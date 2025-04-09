defmodule Cocktailparty.Catalog.Certstream do
  use Cocktailparty.Catalog.SourceBehaviour
  use GenServer

  alias Phoenix.Socket.Broadcast
  require Logger

  @impl Cocktailparty.Catalog.SourceBehaviour
  def required_fields do
    SourceType

    {:ok, required_fields} =
      Cocktailparty.Catalog.SourceType.get_required_fields("certstream", "certstream")

    required_fields
  end

  def start_link(%Cocktailparty.Catalog.Source{} = source) do
    GenServer.start_link(__MODULE__, source, name: {:global, {:source, source.id}})
  end

  @impl GenServer
  def init(source) do
    with conn_pid <- :global.whereis_name({"certstream", source.connection_id}) do
      # Tell the connection process to send the packet this way

      Enum.map(DynamicSupervisor.which_children(conn_pid), fn {_, x, _, _} ->
        send(
          x,
          {:subscribe,
           %{
             name: {:source, source.id},
             mode: source.config["mode"]
           }}
        )
      end)

      {:ok,
       %{
         source: source
       }}
    end
  end

  @impl GenServer
  # Receiving a message from a websocket we are subscribed to.
  def handle_info({_message_type_atom, message}, state) do
    # wrap messages into %Broadcast{} to keep metadata about the payload
    broadcast = %Broadcast{
      topic: "feed:" <> Integer.to_string(state.source.id),
      event: :new_text_message,
      payload: message
    }

    :ok =
      Phoenix.PubSub.broadcast(
        Cocktailparty.PubSub,
        "feed:" <> Integer.to_string(state.source.id),
        broadcast
      )

    :telemetry.execute([:cocktailparty, :broker], %{count: 1}, %{
      feed: "feed:" <> Integer.to_string(state.source.id)
    })

    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.info("Dummy websocket source #{state.source.id} terminating because #{reason}")

    with conn_pid <- :global.whereis_name({"websocket", state.source.connection_id}) do
      # Tell the connection process that we terminate
      send(conn_pid, {:unsubscribe, {:source, state.source.id}, state.source.mode})
    end
  end
end
