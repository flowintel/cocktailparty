defmodule Cocktailparty.Input.RedisPubSub do
  @behaviour Cocktailparty.Input.ConnectionBehavior
  require Logger

  def start_link(connection) do
    Logger.info("Supervisor Starting #{connection.name} redix pubsub driver")

    opts = [
      [
        host: connection.config["hostname"],
        port: connection.config["port"],
        name: {:global, {connection.type, connection.id}}
      ]
    ]

    # Add to the ConnectionDynamicSupervisor children
    case :global.whereis_name(Cocktailparty.ConnectionsDynamicSupervisor) do
      :undefined ->
        {:stop, {:error, "ConnectionsDynamicSupervisor not found"}}

      pid ->
        DynamicSupervisor.start_child(
          pid,
          %{
            id: Redix.PubSub,
            start: {Redix.PubSub, :start_link, opts}
          }
        )
    end
  end

  def validate_config(config) do
    # TODO implement uri
    required_keys = ["hostname", "port"]

    case Enum.all?(required_keys, &Map.has_key?(config, &1)) do
      true -> :ok
      false -> {:error, "Missing required keys in config"}
    end
  end
end
