defmodule Cocktailparty.SinkCatalog.SinkType do
  @moduledoc """
  Defines the available sink types for each connection type.
  """

  # The connection type MUST be fullduplex otherwise it will introduce non controlled bugs.
  @sink_types %{
    "redis" => [
      %{type: "pub", module: Cocktailparty.SinkCatalog.RedisChannelSink, required_fields: [:channel]}
    ]
  }

  @doc """
  Returns the list of source types available for the given connection type.
  """
  def get_sink_types_for_connection(connection_type) do
    Map.get(@sink_types, connection_type, [])
  end

  @doc """
  Returns the module associated with the given connection type and source type.
  """
  def get_module(connection_type, sink_type) do
    @sink_types
    |> Map.get(connection_type, [])
    |> Enum.find(fn %{type: type} -> type == sink_type end)
    |> case do
      %{module: module} -> {:ok, module}
      nil -> {:error, :unknown_source_type}
    end
  end

  @doc """
  Returns the required fields for the given connection type and source type.
  """
  def get_required_fields(connection_type, sink_type) do
    @sink_types
    |> Map.get(connection_type, [])
    |> Enum.find(fn %{type: type} -> type == sink_type end)
    |> case do
      %{required_fields: fields} -> {:ok, fields}
      _ -> {:error, :unknown_source_type}
    end
  end
end
