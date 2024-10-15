defmodule Cocktailparty.Input.StompPubSub do
  @moduledoc false

  use GenServer
  require Logger

  alias Barytherium.Frame
  alias Barytherium.Network
  alias Barytherium.Network.Sender
  alias Cocktailparty.Input
  alias Cocktailparty.Util

  @run_interval 10_000

  defstruct host: "localhost",
            port: 61613,
            login: nil,
            passcode: nil,
            virtual_host: "/",
            ssl: false,
            subscriptions: %{},
            subscribing: %{},
            network_pid: nil,
            connection_id: nil

  ## Public API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def subscribe(pubsub, destination, name) do
    GenServer.cast(pubsub, {:subscribe, destination, name})
  end

  def unsubscribe(pubsub, destination, name) do
    GenServer.cast(pubsub, {:unsubscribe, destination, name})
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
      ready: false,
      network_pid: nil,
      connection_id: Keyword.get(opts, :connection_id)
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    {:ok, network_pid} = connect(state)

    {:noreply, Map.put(state, :network_pid, network_pid)}
  end

  @impl true
  def handle_info(:reconnect, state) do
    Logger.info("Reconnecting to #{state.host}:#{state.port}")
    # Kill the disconnected process
    if state.network_pid do
      Process.exit(state.network_pid, :kill)
    end

    {:ok, network_pid} = connect(state)
    {:noreply, Map.put(state, :network_pid, network_pid)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # do the translation between pid and source name
    name = Util.get_global_name(pid)
    # TODO haha cannot get it's name it is already dead.
    Logger.info("Process #{name} has been terminated")
    # Remove the dead pid from all subscriptions
    new_subscriptions = remove_process_from_subscriptions(state.subscriptions, name)
    {:noreply, %{state | subscriptions: new_subscriptions}}
  end

  def handle_cast({:subscribe, destination, name}, state) do
    with pid <- :global.whereis_name(name) do
      Logger.info("Received SUB from #{:erlang.pid_to_list(pid) |> to_string}")

      # If the connection is ready we can start subscribing right away
      if state.ready do
        Logger.info("Connection is ready, SUBSCRIBING")
        subscribers = Map.get(state.subscriptions, destination, MapSet.new())
        new_subscribers = MapSet.put(subscribers, name)
        new_subscriptions = Map.put(state.subscriptions, destination, new_subscribers)

        # Send SUBSCRIBE frame if this is the first subscriber to the destination
        if MapSet.size(subscribers) == 0 do
          send_subscribe_frame(state.sender_pid, destination)
        end

        # We monitor the process to handle subscriptions
        Process.monitor(pid)

        {:noreply, Map.put(state, :subscriptions, new_subscriptions)}
      else
        Logger.info("Connection is not ready, keeping for later")
        # Otherwise we don't do anything, the driver will reconnect all the source anyway
      end
    else
      :undefined ->
        Logger.info("Cannot find process #{name}")
    end
  end

  def handle_cast({:unsubscribe, destination, name}, state) do
    # We remove the process from the list of processes that receive the frame to this destination
    # if this is the last one, we send an unsubscribe frame
    # if the network is not ready there is nothing to do
    subscribers = Map.get(state.subscriptions, destination, MapSet.new())
    new_subscribers = MapSet.delete(subscribers, name)

    # TODO this is broken ATM
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

  # ERROR on CONNECT
  def handle_cast(
        {:barytherium, :connect, {:error, error}},
        state = %{host: host, port: port}
      ) do
    Logger.error("Stomp Connection to #{host}:#{port} failed, error: #{error}")
    Process.send_after(self(), :reconnect, @run_interval)
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
              # we monitor the process to handle subscriptions
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

    {:noreply, Map.put(state, :subscriptions, new_subscriptions) |> Map.put(:ready, true)}
  end

  # # RECEIVING DATA
  def handle_cast({:barytherium, :frames, {frames, sender_pid}}, state) do
    # Logger.info("Received frames: " <> inspect(frames, binaries: :as_strings))

    Enum.map(frames, fn frame ->
      # Logger.info("Unpacked frame: " <> inspect(frame, binaries: :as_strings))

      # destination = Frame.headers_to_map(frame.headers)["destination"]
      # looking into subscription to simplify the filtering and
      # accomodate weird server behaviours when setting destinations...
      subscription = Frame.headers_to_map(frame.headers)["subscription"]

      subscribers = Map.get(state.subscriptions, subscription, MapSet.new())

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

  @impl true
  def handle_cast({:barytherium, :disconnect, reason}, state) do
    Logger.info("STOMP disconnected because #{reason}")
    # We destroy the subscription map, we have to reconnect anyway
    Process.send_after(self(), :reconnect, @run_interval)
    # {:noreply, %{state | subscriptions: new_subscriptions}}
    {:noreply, Map.put(state, :subscriptions, %{}) |> Map.put(:ready, false)}
  end

  @impl true
  def handle_cast({:barytherium, :error, {error, _sender_pid}}, state) do
    Logger.error("STOMP error: #{inspect(error)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.network_pid do
      Process.exit(state.network_pid, :kill)
    end

    :ok
  end

  ## Helper Functions
  defp connect(state) do
    Network.start_link(self(), state.host, state.port, state.opts)
  end

  defp send_subscribe_frame(sender_pid, destination) do
    Sender.write(sender_pid, [
      %Barytherium.Frame{
        command: :subscribe,
        headers: [
          {"id", destination},
          {"destination", destination},
          {"ack", "client"}
        ]
      }
    ])
  end

  defp send_unsubscribe_frame(sender_pid, destination) do
    Sender.write(sender_pid, [
      %Barytherium.Frame{
        command: :unsubscribe,
        headers: [
          {"id", destination},
          {"destination", destination},
          {"ack", "client"}
        ]
      }
    ])
  end

  defp remove_process_from_subscriptions(subscriptions, name) do
    subscriptions
    |> Enum.reduce(%{}, fn {destination, subscribers}, acc ->
      new_subscribers = MapSet.delete(subscribers, name)

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
end
