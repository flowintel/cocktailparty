defmodule Cocktailparty.Input.CertstreamWatcher do
  @moduledoc """
  The GenServer responsible for watching a specific CT server. It ticks every 15 seconds via
  `schedule_update`, and uses Process.send_after to trigger new requests to see if there are
  any certificates to fetch and broadcast.
  """
  use GenServer

  @default_http_options [
    timeout: 10_000,
    recv_timeout: 10_000,
    ssl: [{:versions, [:"tlsv1.2"]}],
    follow_redirect: true
  ]

  require Logger

  def start_link({:opts, [name: name, log: log]}) do
    GenServer.start_link(
      __MODULE__,
      %{:operator => log, :url => log["url"], :subscribed => MapSet.new()},
      name: name
    )
  end

  def init(state) do
    # Schedule the initial update to happen between 0 and 3 seconds from now in
    # order to stagger when we hit these servers and avoid a thundering herd sort
    # of issue upstream
    delay = :rand.uniform(30) / 10

    Logger.info(
      "Worker #{inspect(self())} started with url #{state[:url]} and initial start time of #{delay} seconds from now."
    )

    # TODO use handle_continue
    send(self(), :init)

    {:ok, state}
  end

  def http_request_with_retries(full_url, options \\ @default_http_options) do
    # Go ask for the first 512 entries
    Logger.info("Sending GET request to #{full_url}")

    user_agent = {"User-Agent", user_agent()}

    case HTTPoison.get(full_url, [user_agent], options) do
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        response.body
        |> Jason.decode!()

      {:ok, response} ->
        Logger.error(
          "Unexpected status code #{response.status_code} fetching url #{full_url}! Sleeping for a bit and trying again..."
        )

        :timer.sleep(:timer.seconds(10))
        http_request_with_retries(full_url, options)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error(
          "Error: #{inspect(reason)} while GETing #{full_url}! Sleeping for 10 seconds and trying again..."
        )

        :timer.sleep(:timer.seconds(10))
        http_request_with_retries(full_url, options)
    end
  end

  def get_tree_size(state) do
    "#{state[:url]}ct/v1/get-sth"
    |> http_request_with_retries
    |> Map.get("tree_size")
  end

  def handle_info({:ssl_closed, _}, state) do
    Logger.info("Worker #{inspect(self())} got :ssl_closed message. Ignoring.")
    {:noreply, state}
  end

  def handle_info(:init, state) do
    # On first run attempt to fetch 512 certificates, and see what the API returns. However
    # many certs come back is what we should use as the batch size moving forward (at least
    # in theory).

    state =
      try do
        batch_size =
          "#{state[:url]}ct/v1/get-entries?start=0&end=511"
          |> HTTPoison.get!([], @default_http_options)
          |> Map.get(:body)
          |> Jason.decode!()
          |> Map.get("entries")
          |> Enum.count()

        Logger.info(
          "Worker #{inspect(self())} with url #{state[:url]} found batch size of #{batch_size}."
        )

        state = Map.put(state, :batch_size, batch_size)

        # On first run populate the state[:tree_size] key
        state = Map.put(state, :tree_size, get_tree_size(state))

        send(self(), :update)

        state
      rescue
        e ->
          Logger.info(
            "Worker #{inspect(self())} with state #{inspect(state)} blew up because #{inspect(e)}"
          )

          state
      end

    # send(self(), :update)

    {:noreply, state}
  end

  def handle_info(:update, state) do
    Logger.debug(fn -> "Worker #{inspect(self())} got tick." end)

    current_tree_size = get_tree_size(state)

    Logger.debug(fn -> "Tree size #{current_tree_size} - #{state[:tree_size]}" end)

    state =
      case current_tree_size > state[:tree_size] do
        true ->
          Logger.info(
            "Worker #{inspect(self())} with url #{state[:url]} found #{current_tree_size - state[:tree_size]} certificates [#{state[:tree_size]} -> #{current_tree_size}]."
          )

          # cert_count = current_tree_size - state[:tree_size]
          # TODO replace by telemetry
          # Instruments.increment("certstream.worker", cert_count, tags: ["url:#{state[:url]}"])

          # Instruments.increment("certstream.aggregate_owners_count", cert_count,
          # tags: [~s(owner:#{state[:operator]["operator_name"]})]
          # )

          broadcast_updates(state, current_tree_size)

          state
          |> Map.put(:tree_size, current_tree_size)
          |> Map.update(:processed_count, 0, &(&1 + (current_tree_size - state[:tree_size])))

        false ->
          state
      end

    schedule_update()

    {:noreply, state}
  end

  def handle_info({:subscribe, %{name: name, mode: mode}}, state) do
    {:noreply,
     Map.put(
       state,
       :subscribed,
       MapSet.put(state.subscribed, {name, mode})
     )}
  end

  def handle_info({:unsubscribe, %{name: name, mode: mode}}, state) do
    with pid <- :global.whereis_name(name) do
      Logger.info("Received UNSUB from #{:erlang.pid_to_list(pid) |> to_string}")
      {:noreply, Map.put(state, :subscribed, MapSet.delete(state.subscribed, {name, mode}))}
    end
  end

  defp broadcast_updates(state, current_size) do
    certificate_count = current_size - state[:tree_size]
    certificates = Enum.to_list((current_size - certificate_count)..(current_size - 1))

    # TODO telemetry event
    Logger.info("Certificate count - #{certificate_count} ")

    certificates
    |> Enum.chunk_every(state[:batch_size])
    # Use Task.async_stream to have 5 concurrent requests to the CT server to fetch
    # our certificates without waiting on the previous chunk.
    |> Task.async_stream(&fetch_and_broadcast_certs(&1, state),
      max_concurrency: 5,
      timeout: :timer.seconds(600)
    )
    # Nop to just pull the requests through async_stream
    |> Enum.to_list()
  end

  def broadcast_to_clients(entries, state) do
    Logger.debug(fn -> "Broadcasting #{length(entries)} certificates to clients" end)

    certificates =
      entries
      |> Enum.map(&%{:message_type => "certificate_update", :data => &1})

    serialized_certificates_full =
      certificates
      |> Enum.map(&Jason.encode!/1)

    certificates_lite =
      certificates
      |> Enum.map(&remove_chain_from_cert/1)
      |> Enum.map(&remove_der_from_cert/1)

    serialized_certificates_lite =
      certificates_lite
      |> Enum.map(&Jason.encode!/1)

    dns_entries_only =
      certificates
      |> Enum.map(&get_in(&1, [:data, :leaf_cert, :all_domains]))
      |> Enum.map(fn dns_entries -> %{:message_type => "dns_entries", :data => dns_entries} end)
      |> Enum.map(&Jason.encode!/1)

    Enum.each(state.subscribed, fn {source, mode} ->
      case :global.whereis_name(source) do
        :undefined ->
          {:source, n} = source
          Process.exit(self(), "Cannot find process \#{:source, #{n}\}")

        pid ->
          case mode do
            "serialized_certificate_full" ->
              Enum.map(serialized_certificates_full, fn x ->
                send(pid, {:serialized_certificate_full, x})
              end)

            "certificate_lite" ->
              Enum.map(certificates_lite, fn x ->
                send(pid, {:certificate_lite, x})
              end)

            "serialized_certificate_lite" ->
              Enum.map(serialized_certificates_lite, fn x ->
                send(pid, {:serialized_certificate_lite, x})
              end)

            "dns_entries_only" ->
              Enum.map(dns_entries_only, fn x ->
                send(pid, {:dns_entries_only, x})
              end)
          end
      end
    end)
  end

  def remove_chain_from_cert(cert) do
    cert
    |> pop_in([:data, :chain])
    |> elem(1)
  end

  def remove_der_from_cert(cert) do
    # Clean the der field from the leaf cert
    cert
    |> pop_in([:data, :leaf_cert, :as_der])
    |> elem(1)
  end

  def fetch_and_broadcast_certs(ids, state) do
    Logger.debug(fn -> "Attempting to retrieve #{ids |> Enum.count()} entries" end)

    entries =
      "#{state[:url]}ct/v1/get-entries?start=#{List.first(ids)}&end=#{List.last(ids)}"
      |> http_request_with_retries
      |> Map.get("entries", [])

    entries
    |> Enum.zip(ids)
    |> Enum.map(fn {entry, cert_index} ->
      entry
      |> Cocktailparty.Input.CertstreamParser.parse_entry()
      |> Map.merge(%{
        :cert_index => cert_index,
        :seen => :os.system_time(:microsecond) / 1_000_000,
        :source => %{
          :url => state[:operator]["url"],
          :name => state[:operator]["description"]
        },
        :cert_link =>
          "#{state[:operator]["url"]}ct/v1/get-entries?start=#{cert_index}&end=#{cert_index}"
      })
    end)
    |> broadcast_to_clients(state)

    entry_count = Enum.count(entries)
    batch_count = Enum.count(ids)

    # If we have *unequal* counts the API has returned less certificates than our initial batch
    # heuristic. Drop the entires we retrieved and recurse to fetch others.
    if entry_count != batch_count do
      Logger.debug(fn ->
        "We didn't retrieve all the entries for this batch, fetching missing #{batch_count - entry_count} entries"
      end)

      fetch_and_broadcast_certs(ids |> Enum.drop(Enum.count(entries)), state)
    end
  end

  # Default to 10 second ticks
  defp schedule_update(seconds \\ 10) do
    # Note, we need to use Kernel.trunc() here to guarentee this is an integer
    # because :timer.seconds returns an integer or a float depending on the
    # type put in, :erlang.send_after seems to hang with floats for some
    # reason :(
    Process.send_after(self(), :update, trunc(:timer.seconds(seconds)))
  end

  defp user_agent do
    "Cocktailparty Server v#{Application.spec(:cocktailparty, :vsn)}"
  end
end
