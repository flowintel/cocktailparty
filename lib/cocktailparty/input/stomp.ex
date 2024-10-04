defmodule Cocktailparty.Input.Stomp do
  @behaviour Cocktailparty.Input.ConnectionBehavior
  require Logger

  def start_link(connection) do
    Logger.info("Supervisor Starting #{connection.name} Stomp PubSub")

    specs =
      {Cocktailparty.Input.StompPubSub,
       host: connection.config["host"],
       port: connection.config["port"],
       virtual_host: connection.config["virtual_host"],
       login: connection.config["login"],
       passcode: connection.config["passcode"],
       ssl: connection.config["ssl"],
       connection_id: connection.id,
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

  def validate_config(config) do
    required_keys = ["host", "port", "virtual_host", "login", "passcode", "ssl"]

    case Enum.all?(required_keys, &Map.has_key?(config, &1)) do
      true -> :ok
      false -> {:error, "Missing required keys in config"}
    end
  end
end
