defmodule Cocktailparty.SinkCatalog.RedisChannelSink do
  use Cocktailparty.SinkCatalog.SinkBehaviour
  use GenServer

  alias Phoenix.PubSub

  require Logger

  alias Redix

  ## Required Fields

  @impl Cocktailparty.SinkCatalog.SinkBehaviour
  def required_fields do
    [:channel]
  end

  ## GenServer Callbacks
  def start_link(%Cocktailparty.SinkCatalog.Sink{} = sink) do
    GenServer.start_link(__MODULE__, sink, name: {:global, {:sink, sink.id}})
  end

  @impl GenServer
  def init(sink) do
    # we subscribe to the sink topic

    :ok =
      PubSub.subscribe(
        Cocktailparty.PubSub,
        "sink:" <> Integer.to_string(sink.id)
      )

    # we keep the redis client's pid in the state
    conn_pid = :global.whereis_name({"redis", sink.connection_id})
    {:ok, %{sink: sink, conn: conn_pid}}

    {:ok,
     %{
       conn_pid: conn_pid,
       channel: sink.config["channel"],
       sink_id: Integer.to_string(sink.id)
     }}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "sink:" <> sink_id, event: :new_client_message, payload: message},
        state)
      when sink_id == state.sink_id do
    case Redix.command(state.conn_pid, ["PUBLISH", state.channel, message]) do
      {:ok, _} ->
        {:noreply, state}

      {:error, reason} ->
        Logger.error(
          "error #{reason} when publishing into redis #{state.conn_pid}:#{state.channel}"
        )

        {:noreply, state}
    end

    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %{redix_conn: redix_conn}) do
    if Process.alive?(redix_conn) do
      Redix.stop(redix_conn)
    end

    :ok
  end
end
