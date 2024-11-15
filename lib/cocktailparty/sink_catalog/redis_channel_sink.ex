defmodule Cocktailparty.SinkCatalog.RedisChannelSink do
  use Cocktailparty.SinkCatalog.SinkBehaviour
  use GenServer

  require Logger

  alias Redix

  ## Required Fields

  @impl Cocktailparty.SinkCatalog.SinkBehaviour
  def required_fields do
    [:channel]
  end

  ## Public API
  @impl Cocktailparty.SinkCatalog.SinkBehaviour
  def publish(pid, message) do
    GenServer.call(pid, {:publish, message})
  end

  ## GenServer Callbacks
  def start_link(%Cocktailparty.SinkCatalog.Sink{} = sink) do
    GenServer.start_link(__MODULE__, sink, name: {:global, {:sink, sink.id}})
  end

  @impl GenServer
  def init(sink) do
    # We just check whether the connection process exists
    with conn_pid <- :global.whereis_name({"redis_pub", sink.connection_id}) do
      # Subscribe to the Redis channel
      {:ok,
       %{
         conn_pid: conn_pid,
         channel: sink.config["channel"],
         source_id: sink.id
       }}
    else
      :undefined -> {:stop, {:connection_not_found, sink.connection_id}}
    end
  end

 #TODO

  @impl GenServer
  def handle_call({:publish, message}, _from, %{redix_conn: redix_conn, channel: channel} = state) do
    case Redix.command(redix_conn, ["PUBLISH", channel, message]) do
      {:ok, _count} ->
        {:reply, :ok, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def terminate(_reason, %{redix_conn: redix_conn}) do
    if Process.alive?(redix_conn) do
      Redix.stop(redix_conn)
    end
    :ok
  end
end
