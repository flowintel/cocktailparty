defmodule Cocktailparty.Catalog.StompSubscribe do
  use Cocktailparty.Catalog.SourceBehaviour
  use GenServer

  alias Phoenix.Socket.Broadcast
  alias Cocktailparty.Catalog.SourceType
  alias Cocktailparty.Input.StompPubSub
  alias Barytherium.Frame
  require Logger

  @impl Cocktailparty.Catalog.SourceBehaviour
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
      # The stomp_pub_sub driver is not monitoring this process
      # we trap the exit and send :unsubscribe request on termination
      Process.flag(:trap_exit, true)

      # Subscribe to the STOMP channel
      StompPubSub.subscribe(conn_pid, source.config["destination"], {:source, source.id})

      {:ok,
       %{
         conn_id: source.connection_id,
         channel: source.config["destination"],
         source_id: source.id
       }}
    else
      :undefined -> {:stop, {:connection_not_found, source.connection_id}}
    end
  end


  # Receiving a message from a source we are subscribed to.
  @impl GenServer
  def handle_info({:new_stomp_message, frame = %Frame{}}, state) do
    headers = Frame.headers_to_map(frame.headers)

    broadcast = %Broadcast{
      topic: "feed:" <> Integer.to_string(state.source_id),
      event: :new_stomp_message,
      payload: %{destination: headers["destination"], body: frame.body |> decompress_body()}
    }

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

  @impl true
  def terminate(reason, state) do
    Logger.info("Terminating stomp subscribe source process #{state.source_id} because: #{reason}")
    conn_pid = :global.whereis_name({"stomp", state.conn_id})
    # we unsubscribe here so the drive should not get irrelevant message from the server
    StompPubSub.unsubscribe(conn_pid, state.channel, {:source, state.source_id})
  end

  defp decompress_body(<<31, 139, 8, _::binary>> = body), do: :zlib.gunzip(body)
  defp decompress_body(<<_::binary>> = body), do: body
end
