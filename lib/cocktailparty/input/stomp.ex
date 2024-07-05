defmodule Cocktailparty.Input.Stomp do
  @behaviour Cocktailparty.Input.ConnectionBehavior

  def start_link(_config) do
    {:error, "Not started"}
    # Implement rabbitmq stomp connection logic
  end

  def validate_config(config) do
    required_keys = ["hostname", "port", "username", "password"]

    case Enum.all?(required_keys, &Map.has_key?(config, &1)) do
      true -> :ok
      false -> {:error, "Missing required keys in config"}
    end
  end
end