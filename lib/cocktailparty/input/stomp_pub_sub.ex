defmodule Cocktailparty.Input.StompPubSub do
  @moduledoc false

  use GenServer
  require Logger

  alias Barytherium.Frame
  alias Barytherium.Network
  alias Barytherium.Network.Sender
  alias Cocktailparty.Input
  import Cocktailparty.Util

  defstruct host: "localhost",
            port: 61613,
            login: nil,
            passcode: nil,
            virtual_host: "/",
            ssl: false,
            subscriptions: %{},
            stomp_conn: nil,
            sender_pid: nil,
            connection_id: nil

  ## Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  # TODO we should subscribe by name, not by pid
  def subscribe(pubsub, destination, pid) do
    GenServer.call(pubsub, {:subscribe, destination, pid})
  end

  # TODO we should unsubscribe by name, not by pid
  def unsubscribe(pubsub, destination, pid) do
    GenServer.call(pubsub, {:unsubscribe, destination, pid})
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    state = %{
      host: Keyword.get(opts, :host, "localhost"),
      port: Keyword.get(opts, :port, 61613),
      virtual_host: Keyword.get(opts, :virtual_host, "/"),
      login: Keyword.get(opts, :login),
      passcode: Keyword.get(opts, :passcode),
      opts: [secure: Keyword.get(opts, :ssl, false)],
      subscriptions: %{},
      stomp_conn: self(),
      sender_pid: nil,
      connection_id: Keyword.get(opts, :connection_id)
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    {:ok, sender_pid} =
      Network.start_link(self(), state.host, state.port, state.opts)

    {:noreply, Map.put(state, :sender_pid, sender_pid)}
  end

  @impl true
  def handle_call({:subscribe, destination, name}, _from, state) do
    with pid <- :global.whereis_name(name) do
      # We monitor the process
      Process.monitor(pid)

      subscribers = Map.get(state.subscriptions, destination, MapSet.new())
      new_subscribers = MapSet.put(subscribers, name)
      new_subscriptions = Map.put(state.subscriptions, destination, new_subscribers)

      # Send SUBSCRIBE frame if this is the first subscriber to the destination
      if MapSet.size(subscribers) == 0 do
        send_subscribe_frame(state, destination)
      end

      # {:reply, :ok, %{state | subscriptions: new_subscriptions}}
      {:reply, :ok, Map.put(state, :subscriptions, new_subscriptions)}
    else
      :undefined ->
        Logger.info("Cannot find process #{name}")
    end
  end

  @impl true
  def handle_call({:unsubscribe, destination, pid}, _from, state) do
    subscribers = Map.get(state.subscriptions, destination, MapSet.new())
    new_subscribers = MapSet.delete(subscribers, pid)

    new_subscriptions =
      if MapSet.size(new_subscribers) == 0 do
        # Send UNSUBSCRIBE frame if no subscribers left
        send_unsubscribe_frame(state, destination)
        Map.delete(state.subscriptions, destination)
      else
        Map.put(state.subscriptions, destination, new_subscribers)
      end

    {:reply, :ok, Map.put(state, :subscriptions, new_subscriptions)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove the dead pid from all subscriptions
    new_subscriptions = remove_pid_from_subscriptions(state.subscriptions, pid)
    {:noreply, %{state | subscriptions: new_subscriptions}}
  end

  # Handle messages from Barytherium
  # CONNECT
  @impl true
  def handle_cast(
        {:barytherium, :connect, {:ok, sender_pid}},
        state = %{
          host: host,
          port: port,
          virtual_host: virtual_host,
          login: login,
          passcode: passcode
        }
      ) do
    Logger.info("Connection to #{host}:#{port} succeeded, remote end has picked up")

    Sender.write(sender_pid, [
      %Frame{
        command: :connect,
        headers: [
          {"accept-version", "1.2"},
          {"host", virtual_host},
          {"heart-beat", "5000,5000"},
          {"login", login},
          {"passcode", passcode}
        ]
      }
    ])

    {:noreply, state}
  end

  # CONNECTED SET DESTINATIONS
  def handle_cast(
        {:barytherium, :frames, {[frame = %Frame{command: :connected}], sender_pid}},
        state
      ) do
    Logger.info(
      "#{state.host}:#{state.port} Received connected frame: " <>
        inspect(frame, binaries: :as_strings)
    )

    # we list all associated destinations/sources and send subscribe frames
    new_subscriptions =
      Enum.reduce(
        Input.get_connection!(state.connection_id).sources,
        state.subscriptions,
        fn source, acc ->
          Logger.info("Sending subscribe frame with destination #{source.config["destination"]}")

          case :global.whereis_name({:source, source.id}) do
            :undefined ->
              Logger.info("Cannot find process #{{:source, source.id}}")
              acc

            pid ->
              # We monitor the process
              Process.monitor(pid)

              subscribers = Map.get(acc, source.config["destination"], MapSet.new())
              new_subscribers = MapSet.put(subscribers, {:source, source.id})

              # Send SUBSCRIBE frame if this is the first subscriber to the destination
              if MapSet.size(subscribers) == 0 do
                # send_subscribe_frame(state, source.config["destination"])
                Sender.write(sender_pid, [
                  %Barytherium.Frame{
                    command: :subscribe,
                    headers: [
                      {"id", source.config["destination"]},
                      {"destination", source.config["destination"]},
                      {"ack", "client"}
                    ]
                  }
                ])
              end

              Map.put(acc, source.config["destination"], new_subscribers)
          end
        end
      )

    {:noreply, Map.put(state, :subscriptions, new_subscriptions)}
  end

  # # RECEIVING DATA
  def handle_cast({:barytherium, :frames, {frames, sender_pid}}, state) do
    # Logger.info("Received frames: " <> inspect(frames, binaries: :as_strings))

    Enum.map(frames, fn frame ->
      # Logger.info("Unpacked frame: " <> inspect(frame, binaries: :as_strings))

      destination = Frame.headers_to_map(frame.headers)["destination"]

      subscribers = Map.get(state.subscriptions, destination, MapSet.new())

      Enum.each(subscribers, fn name ->
        case :global.whereis_name(name) do
          :undefined ->
            Logger.info("Cannot find process #{name}")

          pid ->
            send(pid, {:new_stomp_message, frame})
        end
      end)
    end)

    List.last(frames) |> acknowledge_frame(sender_pid)
    {:noreply, state}
  end

  def handle_cast(
        {:barytherium, :connect, {:error, error}},
        state = %{host: host, port: port}
      ) do
    Logger.error("Stomp Connection to #{host}:#{port} failed, error: #{error}")
    {:stop, :connect_disconnected, state}
  end

  @impl true
  def handle_cast({:barytherium, :disconnect, _sender_pid}, state) do
    Logger.info("STOMP disconnected")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:barytherium, :error, {error, _sender_pid}}, state) do
    Logger.error("STOMP error: #{inspect(error)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.stomp_conn do
      :ok
      # TODO
      # Barytherium.Network.disconnect(state.stomp_conn)
    end

    :ok
  end

  ## Helper Functions
  defp send_subscribe_frame(state, destination) do
    frame = %Frame{
      command: "SUBSCRIBE",
      headers: %{
        "destination" => destination,
        "id" => destination,
        "ack" => "auto"
      },
      body: ""
    }

    Logger.info("sending SUB to #{pid_to_string(state.sender_pid)}")

    send_frame(state.sender_pid, frame)
  end

  defp send_unsubscribe_frame(state, destination) do
    frame = %Frame{
      command: "UNSUBSCRIBE",
      headers: %{
        "id" => destination
      },
      body: ""
    }

    send_frame(state.sender_pid, frame)
  end

  defp send_frame(sender_pid, frame) do
    GenServer.call(sender_pid, {:write, frame})
  end

  defp remove_pid_from_subscriptions(subscriptions, pid) do
    subscriptions
    |> Enum.reduce(%{}, fn {destination, subscribers}, acc ->
      new_subscribers = MapSet.delete(subscribers, pid)

      if MapSet.size(new_subscribers) == 0 do
        # Send UNSUBSCRIBE frame if no subscribers left
        send_unsubscribe_frame(acc, destination)
        acc
      else
        Map.put(acc, destination, new_subscribers)
      end
    end)
  end

  defp acknowledge_frame(%Frame{headers: headers}, sender_pid) do
    case headers |> Frame.headers_to_map() |> Map.get("ack") do
      nil -> nil
      ack_id -> Sender.write(sender_pid, [%Frame{command: :ack, headers: [{"id", ack_id}]}])
    end
  end

  ## Public API

  # @doc """
  # Subscribes the given `pid` to the specified STOMP `destination`.

  # ## Examples

  #     StompPubSub.subscribe(pubsub, "destination_name", self())
  # """
  # def subscribe(pubsub, destination, pid \\ self()) when is_pid(pid) do
  #   subscribe(pubsub, destination, pid)
  # end

  # @doc """
  # Unsubscribes the given `pid` from the specified STOMP `destination`.

  # ## Examples

  #     StompPubSub.unsubscribe(pubsub, "destination_name", self())
  # """
  # def unsubscribe(pubsub, destination, pid \\ self()) when is_pid(pid) do
  #   unsubscribe(pubsub, destination, pid)
  # end
end
