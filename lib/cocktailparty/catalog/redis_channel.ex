defmodule Cocktailparty.Catalog.RedisChannel do
  use Cocktailparty.Catalog.SourceBehaviour
  use GenServer

  alias Phoenix.Socket.Broadcast
  require Logger

  @impl Cocktailparty.Catalog.SourceBehaviour
  def required_fields do
    SourceType
    {:ok, required_fields} = Cocktailparty.Catalog.SourceType.get_required_fields("redis_pub_sub", "pubsub")
    required_fields
  end

  def start_link(%Cocktailparty.Catalog.Source{} = source) do
    GenServer.start_link(__MODULE__, source, name: {:global, {:source, source.id}})
  end

  @impl GenServer
  def init(source) do
    with conn_pid <- :global.whereis_name({"redis_pub_sub", source.connection_id}) do
      # Subscribe to the Redis channel
      {:ok, ref} = Redix.PubSub.subscribe(conn_pid, source.config["channel"], self())

      {:ok,
       %{
         conn_pid: conn_pid,
         channel: source.config["channel"],
         source_id: source.id,
         reference: ref
       }}
    # TODO handle with with
    # else
    #   :undefined -> {:stop, {:connection_not_found, source.connection_id}}
    end
  end

  @impl GenServer
  def handle_info({:redix_pubsub, _, _, :subscribed, %{channel: channel}}, state) do
    Logger.info("Subscribed to #{channel}")
    {:noreply, state}
  end

  # Coming from redix pubsub, messages contain %{channel: channel, payload: payload}
  # https://hexdocs.pm/redix/Redix.PubSub.html#module-messages
  # Receiving a message from a source we are subscribed to.
  def handle_info({:redix_pubsub, _, _, :message, message}, state) do
    # wrap messages into %Broadcast{} to keep metadata about the payload
    broadcast = %Broadcast{
      topic: "feed:" <> Integer.to_string(state.source_id),
      event: :new_message,
      payload: message
    }

    # brokers are listening only to one redis.pubsub
    # so there is no channel name collisions
    # feed:channel_id
    # TODO don't raise, log and add metric of failures
    :ok =
      Phoenix.PubSub.broadcast(
        Cocktailparty.PubSub,
        "feed:" <> Integer.to_string(state.source_id),
        broadcast
      )

    :telemetry.execute([:cocktailparty, :broker], %{count: 1}, %{
      feed: "feed:" <> Integer.to_string(state.source_id)
    })

    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.info(
      "Redis PubSub source #{state.source_id} unsubscribing from #{state.channel} because #{reason}"
    )

    Redix.PubSub.unsubscribe(state.conn_pid, state.source_id, self())
  end
end
