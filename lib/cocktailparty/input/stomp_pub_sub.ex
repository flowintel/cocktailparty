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
            sender_pid: nil,
            network_ref: nil,
            connection_id: nil

  ## Public API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def subscribe(pubsub, destination, name) do
    :ok = GenServer.cast(pubsub, {:subscribe, destination, name})
  end

  def unsubscribe(pubsub, destination, name) do
    :ok = GenServer.cast(pubsub, {:unsubscribe, destination, name})
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
      sender_pid: nil,
      network_ref: nil,
      connection_id: Keyword.get(opts, :connection_id)
    }

      # We monitor the network process, so we have to kill ourself on termination
      Process.flag(:trap_exit, true)

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
    # Are we are monitoring and not linking, the present process does not exit
    if state.network_pid do
      Process.exit(state.network_pid, :kill)
    end

    {:ok, network_pid} = connect(state)
    {:noreply, Map.put(state, :network_pid, network_pid)}
  end

  def handle_cast({:subscribe, destination, name = {:source, srcid}}, state) do
    with pid <- :global.whereis_name(name) do
      Logger.info("Received SUB from #{:erlang.pid_to_list(pid) |> to_string}")

      # If the connection is ready we can start subscribing right away
      if state.ready do
        Logger.info("Connection is ready, SUBSCRIBING to #{destination}")
        subscribers = Map.get(state.subscriptions, destination, MapSet.new())
        new_subscribers = MapSet.put(subscribers, name)
        new_subscriptions = Map.put(state.subscriptions, destination, new_subscribers)

        # Send SUBSCRIBE frame if this is the first subscriber to the destination
        if MapSet.size(subscribers) == 0 do
          send_subscribe_frame(state.sender_pid, destination)
        end

        {:noreply, Map.put(state, :subscriptions, new_subscriptions)}
      else
        # Otherwise we don't do anything, the driver will reconnect all the source anyway
        Logger.info("Connection is not ready -- Subscription for #{srcid} will occur once ready")
      end
    # TODO handle error with with
    # else
    #   :undefined ->
    #     Logger.info("Cannot find process #{name}")
    #     {:noreply, state}
    end
  end

  def handle_cast({:unsubscribe, destination, name = {:source, src}}, state) do
    # Logger.info("Received UNSUB from #{:erlang.pid_to_list(pid) |> to_string}")
    Logger.info("Received UNSUB from #{destination} from #{src}")
    # We remove the process from the list of processes that receive the frame to this destination
    # if this is the last one, we send an unsubscribe frame
    # if the network is not ready there is nothing to do
    if state.ready do
      subscribers = Map.get(state.subscriptions, destination, MapSet.new())
      new_subscribers = MapSet.delete(subscribers, name)

      new_subscriptions =
        if MapSet.size(new_subscribers) == 0 do
          # Send UNSUBSCRIBE frame if no subscribers left
          Logger.info("Connection is ready, UNSUBSCRIBING")
          send_unsubscribe_frame(state.sender_pid, destination)
          Map.delete(state.subscriptions, destination)
        else
          Map.put(state.subscriptions, destination, new_subscribers)
        end

      {:noreply, Map.put(state, :subscriptions, new_subscriptions)}
    else
      {:noreply, state}
    end
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

    {:noreply, %{state | sender_pid: sender_pid}}
  end

  # ERROR on CONNECT
  def handle_cast(
        {:barytherium, :connect, {:error, error}},
        state = %{host: host, port: port}
      ) do
    Logger.error("Stomp Connection to #{host}:#{port} failed, error: #{error}")
    Process.send_after(self(), :reconnect, @run_interval)
    {:noreply, state |> Map.put(:ready, false)}
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

            _ ->
              subscribers = Map.get(acc, source.config["destination"], MapSet.new())
              new_subscribers = MapSet.put(subscribers, {:source, source.id})

              # Send SUBSCRIBE frame if this is the first subscriber to the destination
              if MapSet.size(subscribers) == 0 do
                send_subscribe_frame(state.sender_pid, source.config["destination"])
              end

              Map.put(acc, source.config["destination"], new_subscribers)
          end
        end
      )

    {:noreply,
     Map.put(state, :subscriptions, new_subscriptions)
     |> Map.put(:sender_pid, sender_pid)
     |> Map.put(:ready, true)}
  end

  # RECEIVING DATA
  def handle_cast({:barytherium, :frames, {frames, sender_pid}}, state) do
    # Logger.info("Received frames: " <> inspect(frames, binaries: :as_strings))

    Enum.map(frames, fn frame ->
      # Logger.info("Unpacked frame: " <> inspect(frame, binaries: :as_strings))

      # looking into subscription to simplify the filtering and
      # accomodate weird server behaviours when setting destinations...
      subscription = Frame.headers_to_map(frame.headers)["subscription"]

      subscribers = Map.get(state.subscriptions, subscription, MapSet.new())

      Enum.each(subscribers, fn name ->
        case :global.whereis_name(name) do
          :undefined ->
            {:source, n} = name
            Logger.info("Cannot find process #{n}")

          pid ->
            send(pid, {:new_stomp_message, frame})
        end
      end)
    end)

    List.last(frames) |> acknowledge_frame(sender_pid)

    {:noreply, Map.put(state, :sender_pid, sender_pid) |> Map.put(:ready, true)}
  end

  @impl true
  def handle_cast({:barytherium, :disconnect, reason}, state) do
    Logger.info("STOMP disconnected because #{reason}")
    # We destroy the subscription map, we have to reconnect anyway
    Process.send_after(self(), :reconnect, @run_interval)
    {:noreply, Map.put(state, :subscriptions, %{}) |> Map.put(:ready, false)}
  end

  @impl true
  def handle_cast({:barytherium, :error, {error, _sender_pid}}, state) do
    # STOMP error can occur when subscribing to a destination fails
    # We just bail
    Logger.error("STOMP error: #{inspect(error)}")
    Process.send_after(self(), :reconnect, @run_interval)
    {:noreply, Map.put(state, :subscriptions, %{}) |> Map.put(:ready, false)}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("Cleaning after Stomp connection #{state.connection_id}")
    if state.network_pid do
      Process.exit(state.network_pid, :kill)
    end
  end

  defp connect(state) do
    init_state = %{
      opts: state.opts,
      host: state.host,
      port: state.port,
      callback_handler: self()
    }

    case GenServer.start(Network, init_state, []) do
      {:ok, pid} ->
        Logger.info("network pid: #{Util.pid_to_string(pid)}")
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_subscribe_frame(sender_pid, destination) do
    Sender.write(sender_pid, [
      %Barytherium.Frame{
        command: :subscribe,
        headers: [
          # We share the STOMP id as we multiplex subscriptions:
          # There is only on STOMP subscription for potentially
          # several cocktailparty sources
          {"id", destination},
          {"destination", destination},
          # We use client mode so the sender will send again messages
          # that we did not (cumulatively) acknowledged
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
          {"id", destination}
        ]
      }
    ])
  end

  defp acknowledge_frame(%Frame{headers: headers}, sender_pid) do
    case headers |> Frame.headers_to_map() |> Map.get("ack") do
      nil -> nil
      ack_id -> Sender.write(sender_pid, [%Frame{command: :ack, headers: [{"id", ack_id}]}])
    end
  end
end
