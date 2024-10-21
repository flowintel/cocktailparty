defmodule Cocktailparty.Input.Redis do
  @behaviour Cocktailparty.Input.ConnectionBehavior
  require Logger

  def start_link(connection) do
    Logger.info("Supervisor Starting #{connection.name} redix driver")

    specs =
      {Redix,
       host: connection.config["hostname"],
       port: connection.config["port"],
       name: {:global, {connection.type, connection.id}}}

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
