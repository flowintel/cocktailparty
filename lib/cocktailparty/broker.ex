defmodule Cocktailparty.Broker do
  use GenServer
  alias Redix.PubSub

  alias Cocktailparty.Catalog
  require Logger

  defstruct [
    :pubsub,
    :redis_instance,
    subscribed: [%{source: nil, ref: nil}],
    subscribing: [%{source: nil, ref: nil}]
  ]

  def start_link(redis_instance: rc, name: name) do
    GenServer.start_link(__MODULE__, redis_instance: rc, name: name)
  end

  def init(redis_instance: redis_instance, name: _) do
    {:ok, pubsub} =
      PubSub.start_link(
        host: redis_instance.hostname,
        port: redis_instance.port,
        name: {:global, "pubsub" <> redis_instance.name}
      )

    Logger.info("Starting pubsub for #{redis_instance.name}")

    # Get sources from the catalog
    sources = Catalog.list_redis_instance_sources(redis_instance.id)

    subscribing =
      Enum.reduce(sources, [], fn source, subscribing ->
        # Subscribe to each source
        Logger.info("Subscribing to #{source.name}")
        {:ok, ref} = PubSub.subscribe(pubsub, "#{source.channel}", self())
        [%{source: source, ref: ref} | subscribing]
      end)

    {:ok,
     %{subscribing: subscribing, pubsub: pubsub, subscribed: [], redis_instance: redis_instance}}
  end

  # Receiving a connection notification from Redix about source we are subscribing to.
  def handle_info({:redix_pubsub, _pid, ref, :subscribed, _message}, state) do
    # Find the source that we are subscribing to
    current_sub = Enum.find(state.subscribing, fn subscribing -> subscribing.ref == ref end)
    # Remove the source from the list of sources we are subscribing to
    subscribing = Enum.reject(state.subscribing, fn subscribing -> subscribing.ref == ref end)
    # Add the source to the list of sources we are subscribed to
    subscribed = [%{source: current_sub.source, ref: ref} | state.subscribed]
    # Update the state
    state = %{
      subscribing: subscribing,
      subscribed: subscribed,
      pubsub: state.pubsub,
      redis_instance: state.redis_instance
    }

    # Log the subscription
    Logger.info("Subscribed to #{current_sub.source.name}")
    {:noreply, state}
  end

  # Receiving a deconnection notification from Redix about a source we are subscribed to.
  def handle_info({:redix_pubsub, _pid, ref, :disconnected, _message}, state) do
    # Find the source that is disconnecting
    current_sub = Enum.find(state.subscribed, fn subscribed -> subscribed.ref == ref end)
    # Remove the source from the list of sources we are subscribed to
    subscribed = Enum.reject(state.subscribed, fn subscribed -> subscribed.ref == ref end)
    # Add the sources to the list of sources we are subscribing to
    subscribing = [%{source: current_sub.source, ref: ref} | state.subscribing]
    # Update the state
    state = %{
      subscribing: subscribing,
      subscribed: subscribed,
      pubsub: state.pubsub,
      redis_instance: state.redis_instance
    }

    Logger.info("Disconnected from #{inspect(current_sub.source.name)}")
    {:noreply, state}
  end

  # Coming from redix pubsub, messages contain %{channel: channel, payload: payload}
  # https://hexdocs.pm/redix/Redix.PubSub.html#module-messages
  # Receiving a message from a source we are subscribed to.
  def handle_info({:redix_pubsub, _pid, ref, :message, message}, state) do
    current_sub = Enum.find(state.subscribed, fn subscribed -> subscribed.ref == ref end)

    # brokers are listening only to on redis.pubsub
    # so there is no channel name collisions
    # feed:channel_id
    :ok =
      Phoenix.PubSub.broadcast!(
        Cocktailparty.PubSub,
        "feed:" <> Integer.to_string(current_sub.source.id),
        message
      )

    {:noreply, state}
  end

  # Receiving Redix confirmation that we unsubcribed from a source.
  def handle_info({:redix_pubsub, _pid, ref, :unsubscribed, _message}, state) do
    # find the source, the source can be subscribed or reconnecting (subscribing)
    current_sub =
      case Enum.find(state.subscribed, fn subscribed -> subscribed.ref == ref end) do
        nil ->
          Enum.find(state.subscribing, fn subscribing -> subscribing.ref == ref end)

        current_sub ->
          current_sub
      end

    Logger.info("Unsubscribed from #{inspect(current_sub.source.name)}")

    # Remove any reference from the state
    subscribing = Enum.reject(state.subscribing, fn subscribing -> subscribing.ref == ref end)

    subscribed = Enum.reject(state.subscribed, fn subscribed -> subscribed.ref == ref end)

    {:noreply,
     %{
       subscribing: subscribing,
       pubsub: state.pubsub,
       subscribed: subscribed,
       redis_instance: state.redis_instance
     }}
  end

  # A new source has been insert into the catalog, subscribe to it.
  def handle_cast({:new_source, source}, state) do
    Logger.info("New source, Subscribing to #{source.name}")
    {:ok, ref} = PubSub.subscribe(state.pubsub, "#{source.channel}", self())
    subscribing = [%{source: source, ref: ref} | state.subscribing]

    {:noreply,
     %{
       subscribing: subscribing,
       pubsub: state.pubsub,
       subscribed: state.subscribed,
       redis_instance: state.redis_instance
     }}
  end

  # A source has been deleted from the catalog, unsubscribe from it.
  def handle_cast({:delete_source, source}, state) do
    Logger.info("Source deleted, Unsubscribing from #{source.name}")
    # find the reference
    current_sub =
      case Enum.find(state.subscribed, fn subscribed -> subscribed.source.id == source.id end) do
        nil ->
          case Enum.find(state.subscribing, fn subscribing ->
                 subscribing.source.id == source.id
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
    :ok = PubSub.unsubscribe(state.pubsub, "#{current_sub.source.channel}", self())

    {:noreply,
     %{
       subscribing: state.subscribing,
       pubsub: state.pubsub,
       subscribed: state.subscribed,
       redis_instance: state.redis_instance
     }}
  end
end
