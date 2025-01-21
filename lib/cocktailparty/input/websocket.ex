defmodule Cocktailparty.Input.WebSocket do
  @behaviour Cocktailparty.Input.ConnectionBehavior
  require Logger

  def start_link(connection) do
    Logger.info("Supervisor Starting #{connection.name} websocket")

    # TODO have proper validation on YAML fields
    input_datatype = case connection.config["input_datatype"] do
      "text" -> :text
      "binary" -> :binary
    end

    specs =
      {Cocktailparty.Input.WebsocketClient,
       uri: connection.config["uri"],
       state: %{subscribed: MapSet.new(), input_datatype: input_datatype},
       opts: [name: {:global, {connection.type, connection.id}}]}

    # Add to the ConnectionDynamicSupervisor children
    case :global.whereis_name(Cocktailparty.ConnectionsDynamicSupervisor) do
      :undefined ->
        {:stop, {:error, "ConnectionsDynamicSupervisor not found"}}

      pid ->
        DynamicSupervisor.start_child(
          pid,
          specs
        )
    end
  end
end
