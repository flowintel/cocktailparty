defmodule Cocktailparty.Catalog.StompSubscribe do
  use Cocktailparty.Catalog.SourceBase
  use GenServer

  alias Phoenix.Socket.Broadcast
  alias Cocktailparty.Catalog.SourceType
  alias Cocktailparty.Input.StompPubSub
  alias Barytherium.Frame
  require Logger

  @impl Cocktailparty.Catalog.SourceBase
  def required_fields do
    SourceType

    {:ok, required_fields} =
      Cocktailparty.Catalog.SourceType.get_required_fields("stomp", "subscribe")

    required_fields
  end

  def start_link(source) do
    GenServer.start_link(__MODULE__, source, name: {:global, {:source, source.id}})
  end

  @impl GenServer
  def init(source) do
    with conn_pid <- :global.whereis_name({"stomp", source.connection_id}) do
      # Subscribe to the STOMP channel
      StompPubSub.subscribe(conn_pid, source.config["destination"], {:source, source.id})

      {:ok,
       %{
         conn_pid: conn_pid,
         channel: source.config["destination"],
         source_id: source.id
       }}
    else
      :undefined -> {:stop, {:connection_not_found, source.connection_id}}
    end
  end

  # def handle_info({:redix_pubsub, _, _, :subscribed, %{channel: channel}}, state) do
  #   Logger.info("Subscribed to #{channel}")
  #   {:noreply, state}
  # end

  # Coming from redix pubsub, messages contain %{channel: channel, payload: payload}
  # https://hexdocs.pm/redix/Redix.PubSub.html#module-messages
  # Receiving a message from a source we are subscribed to.
  @impl GenServer
  def handle_info({:new_stomp_message, frame = %Frame{}}, state) do
    # Logger.info("source  #{state.source_id} receiving events")
    # wrap messages into %Broadcast{} to keep metadata about the payload
    # broadcast = %Broadcast{
    #   topic: "feed:" <> Integer.to_string(state.source_id),
    #   event: :new_stomp_message,
    #   payload:  inspect(frame, binaries: :as_strings)
    # }

    headers = Frame.headers_to_map(frame.headers)

    broadcast = %Broadcast{
      topic: "feed:" <> Integer.to_string(state.source_id),
      event: :new_stomp_message,
      payload: %{destination: headers["destination"], body: frame.body |> decompress_body()  }
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

  defp decompress_body(<<31, 139, 8, _::binary>> = body), do: :zlib.gunzip(body)
  defp decompress_body(<<_::binary>> = body), do: body
end
