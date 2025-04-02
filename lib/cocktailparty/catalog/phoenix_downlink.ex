defmodule Cocktailparty.Catalog.PhoenixDownlink do
  use Cocktailparty.Catalog.SourceBehaviour
  use GenServer

  alias Phoenix.Socket.Broadcast
  require Logger

  @impl Cocktailparty.Catalog.SourceBehaviour
  def required_fields do
    SourceType

    {:ok, required_fields} =
      Cocktailparty.Catalog.SourceType.get_required_fields("phoenix", "phoenix_downlink")

    required_fields
  end

  def start_link(%Cocktailparty.Catalog.Source{} = source) do
    GenServer.start_link(__MODULE__, source, name: {:global, {:source, source.id}})
  end

  @impl GenServer
  def init(source) do
    with conn_pid <- :global.whereis_name({"phoenix", source.connection_id}) do
      # Tell the connection process to send the packet this way
      GenServer.cast(
        conn_pid,
        {:subscribe,
         %{
           destination: source.config["destination"],
           name: {:source, source.id}
         }}
      )

      {:ok,
       %{
         conn_id: source.connection_id,
         source_id: source.id,
         destination: source.config["destination"],
         input_datatype: source.config["input_datatype"],
         output_datatype: source.config["output_datatype"]
       }}
    end
  end

  @impl GenServer
  # Receiving a message from a websocket we are subscribed to.
  def handle_info({_message_type_atom, message}, state) do
    # wrap messages into %Broadcast{} to keep metadata about the payload
    broadcast =
      case state.output_datatype do
        "text" ->
          %Broadcast{
            topic: "feed:" <> Integer.to_string(state.source_id),
            event: :new_text_message,
            payload: message
          }

        "binary" ->
          %Broadcast{
            topic: "feed:" <> Integer.to_string(state.source_id),
            event: :new_binary_message,
            payload: message
          }
      end

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
    Logger.info("Phoenix Downlink source #{state.source_id} is terminating because #{reason}")

    with conn_pid <- :global.whereis_name({"phoenix", state.connection_id}) do
      # Tell the connection process that we terminate
      GenServer.cast(
        conn_pid,
        {:unsubscribe, %{destination: state.destination, name: {:source, state.source_id}}}
      )
    end
  end
end
