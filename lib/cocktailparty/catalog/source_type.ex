defmodule Cocktailparty.Catalog.SourceType do
  @moduledoc """
  Defines the available source types for each connection type.
  """

  @source_types %{
    "redis_pub_sub" => [
      # TODO change to sub
      %{type: "pubsub", module: Cocktailparty.Catalog.RedisChannel, required_fields: [:channel]}
    ],
    "redis" => [
      %{type: "lpop", module: Cocktailparty.Catalog.RedisLPOP, required_fields: [:key]}
      # %{type: "rpop", module: Cocktailparty.Catalog.Sources.Redis.RPOP}
    ],
    "stomp" => [
      %{
        type: "subscribe",
        module: Cocktailparty.Catalog.StompSubscribe,
        required_fields: [:destination]
      }
    ],
    "websocket" => [
      %{
        type: "dummy",
        module: Cocktailparty.Catalog.DummyWebsocket,
        required_fields: [:output_datatype]
      }
    ]
  }

  @doc """
  Returns the list of source types available for the given connection type.
  """
  def get_source_types_for_connection(connection_type) do
    Map.get(@source_types, connection_type, [])
  end

  @doc """
  Returns the module associated with the given connection type and source type.
  """
  def get_module(connection_type, source_type) do
    @source_types
    |> Map.get(connection_type, [])
    |> Enum.find(fn %{type: type} -> type == source_type end)
    |> case do
      %{module: module} -> {:ok, module}
      nil -> {:error, :unknown_source_type}
    end
  end

  @doc """
  Returns the required fields for the given connection type and source type.
  """
  def get_required_fields(connection_type, source_type) do
    @source_types
    |> Map.get(connection_type, [])
    |> Enum.find(fn %{type: type} -> type == source_type end)
    |> case do
      %{required_fields: fields} -> {:ok, fields}
      _ -> {:error, :unknown_source_type}
    end
  end
end
