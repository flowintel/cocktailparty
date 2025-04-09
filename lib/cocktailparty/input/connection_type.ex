defmodule Cocktailparty.Input.ConnectionTypes do
  @moduledoc """
  Defines available connection types, their associated modules, and required fields.

  fullduplex is the variable responsible for the connection to be able to receive sinks.
  If the connection is full duplex, it MUST have a default_sink_module
  """

  @connection_types %{
    "redis" => %{
      name: "Redis",
      module: Cocktailparty.Input.Redis,
      required_fields: [:hostname, :port],
      fullduplex: true,
      default_sink_module: "pub"
    },
    "redis_pub_sub" => %{
      name: "Redis Subscribe",
      module: Cocktailparty.Input.RedisPubSub,
      required_fields: [:hostname, :port],
      fullduplex: false
    },
    "stomp" => %{
      name: "STOMP",
      module: Cocktailparty.Input.Stomp,
      required_fields: [:host, :port, :virtual_host, :login, :passcode, :ssl],
      fullduplex: false
    },
    "websocket" => %{
      name: "WebSocket",
      module: Cocktailparty.Input.WebSocket,
      required_fields: [:uri, :input_datatype],
      fullduplex: false
    },
    "phoenix" => %{
      name: "phoenix",
      module: Cocktailparty.Input.Phoenix,
      required_fields: [:uri],
      fullduplex: false
    },
    "certstream" => %{
      name: "certstream",
      module: Cocktailparty.Input.CertStream,
      required_fields: [:uri],
      fullduplex: false
    }
    # Add other connection types here
  }

  @doc """
  Returns a list of all available connection types with their names and required fields.
  """
  def all do
    @connection_types
    |> Enum.into(%{}, fn {type, info} ->
      {type, Map.delete(info, :module)}
    end)
  end

  @doc """
  Returns the module associated with the given connection type.

  ## Examples

      iex> Cocktailparty.Input.ConnectionTypes.get_module("redis")
      Cocktailparty.Input.Redis

      iex> Cocktailparty.Input.ConnectionTypes.get_module("unknown_type")
      nil
  """
  def get_module(type) do
    case Map.get(@connection_types, type) do
      %{module: mod} -> mod
      nil -> nil
    end
  end

  @doc """
  Returns the required fields for the given connection type.

  ## Examples

      iex> Cocktailparty.Input.ConnectionTypes.get_required_fields("stomp")
      [:host, :port, :virtual_host, :login, :passcode, :ssl]

      iex> Cocktailparty.Input.ConnectionTypes.get_required_fields("unknown_type")
      []
  """
  def get_required_fields(type) do
    case Map.get(@connection_types, type) do
      %{required_fields: req_fields} -> req_fields
      nil -> []
    end
  end

  @doc """
  Returns the default sink module
  """
  def get_default_sink_module(type) do
    case Map.get(@connection_types, type) do
      %{default_sink_module: mod} -> mod
      nil -> []
    end
  end

  @doc """
  return whether the connection type support fullduplex connections
  """
  def get_full_duplex(type) do
    Map.get(@connection_types, type).fullduplex
  end

  def validate_config(type, config) do
    if config != nil do
      # TODO implement uri
      required_keys = get_required_fields(type)

      case Enum.all?(required_keys, &Map.has_key?(config, Atom.to_string(&1))) do
        true -> :ok
        false -> {:error, "Missing required keys in config"}
      end
    else
      {:error, "Cannot validate config"}
    end
  end
end
