# defmodule Cocktailparty.Input.RedisLPOP do
#   use Cocktailparty.Catalog.SourceBase

#   alias CocktailpartyWeb.Endpoint

#   @impl true
#   def required_fields do
#     [:key]
#   end

#   def start_link(config) do
#     GenServer.start_link(__MODULE__, config, name: via_tuple(config[:id]))
#   end

#   @impl true
#   def init(config) do
#     with {:ok, conn_pid} <- :global.whereis_name("connection" <> config[:connection_id]) do
#       schedule_poll()
#       {:ok, %{conn_pid: conn_pid, key: config[:key], source_id: config[:id]}}
#     else
#       :error -> {:stop, {:connection_not_found, config[:connection_id]}}
#     end
#   end

#   def handle_info(:poll, state) do
#     # Perform LPOP operation
#     case Redix.command(state.conn_pid, ["LPOP", state.key]) do
#       {:ok, nil} ->
#         # No item in the list
#         :ok

#       {:ok, payload} ->
#         # Broadcast the message
#         Endpoint.broadcast("source:#{state.source_id}", "new_message", %{payload: payload})

#         # Emit telemetry event
#         :telemetry.execute([:cocktailparty, :source, :message_received], %{count: 1}, %{source_id: state.source_id})

#       {:error, reason} ->
#         # Handle error
#         Logger.error("Error performing LPOP: #{inspect(reason)}")
#     end

#     schedule_poll()
#     {:noreply, state}
#   end

#   defp schedule_poll do
#     Process.send_after(self(), :poll, 1000)  # Poll every second (adjust as needed)
#   end

#   defp via_tuple(id), do: {:via, Registry, {Cocktailparty.SourceRegistry, id}}
# end
