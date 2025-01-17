defmodule Cocktailparty.Catalog.DummyWebsocket do
  use Cocktailparty.Catalog.SourceBehaviour
  use GenServer

  alias Phoenix.Socket.Broadcast
  require Logger

  @impl Cocktailparty.Catalog.SourceBehaviour
  def required_fields do
    SourceType

    {:ok, required_fields} =
      Cocktailparty.Catalog.SourceType.get_required_fields("websocket", "dummy")

    required_fields
  end

  def start_link(%Cocktailparty.Catalog.Source{} = source) do
    GenServer.start_link(__MODULE__, source, name: {:global, {:source, source.id}})
  end

  @impl GenServer
  def init(source) do
    with conn_pid <- :global.whereis_name({"websocket", source.connection_id}) do
      # Tell the connection process to send the packet this way
      send(
        conn_pid,
        {:subscribe, %{name: {:source, source.id}, datatype: source.config["datatype"]}}
      )

      Logger.error("SENT SUB")

      {:ok,
       %{
         conn_id: source.connection_id,
         source_id: source.id
       }}
    end
  end

  @impl GenServer
  # Receiving a message from a websocket we are subscribed to.
  def handle_info({:new_text_message, message}, state) do
    # wrap messages into %Broadcast{} to keep metadata about the payload
    broadcast = %Broadcast{
      topic: "feed:" <> Integer.to_string(state.source_id),
      event: :new_text_message,
      payload: message
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

  @impl GenServer
  # Receiving a message from a websocket we are subscribed to.
  def handle_info({:new_binary_message, message}, state) do
    # wrap messages into %Broadcast{} to keep metadata about the payload
    broadcast = %Broadcast{
      topic: "feed:" <> Integer.to_string(state.source_id),
      event: :new_binary_message,
      payload: message
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

  @impl GenServer
  def terminate(reason, state) do
    Logger.info("Dummy websocket source #{state.source_id} terminating because #{reason}")

    with conn_pid <- :global.whereis_name({"websocket", state.connection_id}) do
      # Tell the connection process that we terminate
      send(conn_pid, {:unsubscribe, {:source, state.source_id}})
    end
  end
end
