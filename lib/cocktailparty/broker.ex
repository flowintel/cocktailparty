defmodule Cocktailparty.Broker do
  use GenServer
  alias Redix.PubSub

  alias Cocktailparty.Catalog
  alias Phoenix.Socket.Broadcast
  require Logger

  defstruct [
    :pubsub,
    :connection,
    subscribed: [],
    subscribing: []
  ]

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def init(opts) do
    connection = opts[:connection]
    dbg(connection)

    {:ok, pubsub} =
      PubSub.start_link(
        host: connection.config["hostname"],
        port: connection.config["port"],
        name: {:global, "pubsub_" <> Integer.to_string(connection.id)}
      )

    # Logger.info("Starting pubsub for #{connection.name}")
    Logger.info("Starting pubsub for #{connection.id}")

    # Get sources from the catalog
    sources = Catalog.list_connection_sources(connection.id)

    subscribing =
      Enum.reduce(sources, [], fn source, subscribing ->
        # Subscribe to each source
        Logger.info("Subscribing to #{source.name}")
        {:ok, _} = PubSub.subscribe(pubsub, "#{source.channel}", self())
        [source | subscribing]
      end)

    {:ok, %{subscribing: subscribing, pubsub: pubsub, subscribed: [], connection: connection}}
  end

  # Receiving a connection notification from Redix about source we are subscribing to.
  # we don't filter on pid and ref, we started the pubsub process so it only talks to the present process
  def handle_info({:redix_pubsub, _, _, :subscribed, message}, state) do
    # Find the source that we are subscribing to
    current_sub =
      Enum.find(state.subscribing, fn subscribing -> subscribing.channel == message.channel end)

    # Remove the source from the list of sources we are subscribing to
    subscribing =
      Enum.reject(state.subscribing, fn subscribing -> subscribing.channel == message.channel end)

    # Add the source to the list of sources we are subscribed to
    subscribed = [current_sub | state.subscribed]
    # Update the state
    state = %{
      subscribing: subscribing,
      subscribed: subscribed,
      pubsub: state.pubsub,
      connection: state.connection
    }

    # Log the subscription
    Logger.info("Subscribed to #{current_sub.name}")
    {:noreply, state}
  end

  # Receiving a deconnection notification from Redix about a source we are subscribed to.
  def handle_info({:redix_pubsub, _, _, :disconnected, message}, state) do
    # Find the source that is disconnecting
    current_sub =
      Enum.find(state.subscribing, fn subscribing -> subscribing.channel == message.channel end)

    # Remove the source from the list of sources we are subscribed to
    subscribed =
      Enum.reject(state.subscribed, fn subscribed -> subscribed.channel == message.channel end)

    # Add the sources to the list of sources we are subscribing to
    subscribing = [current_sub | state.subscribed]

    # Update the state
    state = %{
      subscribing: subscribing,
      subscribed: subscribed,
      pubsub: state.pubsub,
      connection: state.connection
    }

    Logger.info("Disconnected from #{inspect(current_sub.name)}")
    {:noreply, state}
  end

  # Coming from redix pubsub, messages contain %{channel: channel, payload: payload}
  # https://hexdocs.pm/redix/Redix.PubSub.html#module-messages
  # Receiving a message from a source we are subscribed to.
  def handle_info({:redix_pubsub, _, _, :message, message}, state) do
    current_sub =
      Enum.find(state.subscribed, fn subscribed -> subscribed.channel == message.channel end)

    # wrap messages into %Broadcast{} to keep metadata about the payload
    broadcast = %Broadcast{
      topic: "feed:" <> Integer.to_string(current_sub.id),
      event: :new_redis_message,
      payload: message
    }

    # brokers are listening only to one redis.pubsub
    # so there is no channel name collisions
    # feed:channel_id
    # TODO don't raise, log and add metric of failures
    :ok =
      Phoenix.PubSub.broadcast(
        Cocktailparty.PubSub,
        "feed:" <> Integer.to_string(current_sub.id),
        broadcast
      )

    :telemetry.execute([:cocktailparty, :broker], %{count: 1}, %{
      feed: "feed:" <> Integer.to_string(current_sub.id)
    })

    {:noreply, state}
  end

  # Receiving Redix confirmation that we unsubcribed from a source.
  def handle_info({:redix_pubsub, _, _, :unsubscribed, message}, state) do
    # find the source, the source can be subscribed or reconnecting (subscribing)
    current_sub =
      case Enum.find(state.subscribed, fn subscribed -> subscribed.channel == message.channel end) do
        nil ->
          Enum.find(state.subscribing, fn subscribing ->
            subscribing.channel == message.channel
          end)

        current_sub ->
          current_sub
      end

    Logger.info("Unsubscribed from #{inspect(current_sub.name)}")

    # Remove any reference from the state
    subscribing =
      Enum.reject(state.subscribing, fn subscribing -> subscribing.channel == message.channel end)

    subscribed =
      Enum.reject(state.subscribed, fn subscribed -> subscribed.channel == message.channel end)

    {:noreply,
     %{
       subscribing: subscribing,
       pubsub: state.pubsub,
       subscribed: subscribed,
       connection: state.connection
     }}
  end

  # A new source has been insert into the catalog, subscribe to it.
  def handle_cast({:new_source, source}, state) do
    Logger.info("New source, Subscribing to #{source.name}")
    {:ok, _} = PubSub.subscribe(state.pubsub, "#{source.channel}", self())
    subscribing = [source | state.subscribing]

    {:noreply,
     %{
       subscribing: subscribing,
       pubsub: state.pubsub,
       subscribed: state.subscribed,
       connection: state.connection
     }}
  end

  # A source has been deleted from the catalog, unsubscribe from it.
  def handle_cast({:delete_source, source}, state) do
    Logger.info("Source deleted, Unsubscribing from #{source.name}")
    # find the reference
    current_sub =
      case Enum.find(state.subscribed, fn subscribed -> subscribed.id == source.id end) do
        nil ->
          case Enum.find(state.subscribing, fn subscribing ->
                 subscribing.id == source.id
               end) do
            nil ->
              # unknown source, do nothing
              {:noreply, state}

            current_sub ->
              current_sub
          end

        current_sub ->
          current_sub
      end

    # unsubscribe
    :ok = PubSub.unsubscribe(state.pubsub, "#{current_sub.channel}", self())

    {:noreply,
     %{
       subscribing: state.subscribing,
       pubsub: state.pubsub,
       subscribed: state.subscribed,
       connection: state.connection
     }}
  end
end
