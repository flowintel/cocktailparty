defmodule Cocktailparty.Input.Phoenix do
  @behaviour Cocktailparty.Input.ConnectionBehavior
  require Logger

  def start_link(connection) do
    Logger.info("Supervisor Starting #{connection.name} phoenix / slipstream connection")

    specs =
      {
        Cocktailparty.Input.PhoenixClient,
        uri: connection.config["uri"],
        name: {:global, {connection.type, connection.id}}
      }

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
