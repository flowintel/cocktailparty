defmodule Cocktailparty.Util do
  @doc """
  Translates from map to YAML text representation
  """
  @spec map_to_yaml!(map()) :: String.t()
  def map_to_yaml!(config_map) do
    Ymlr.document!(config_map)
  end

  @doc """
  Translates from map to YAML text representation
  """
  @spec map_to_yaml!(map()) :: String.t()
  def map_to_yaml(config_map) do
    Ymlr.document(config_map)
  end

  @doc """
  Translates from YAML text representation to map
  """
  @spec yaml_to_map!(String.t()) :: map()
  def yaml_to_map!(config_yaml) do
    YamlElixir.read_from_string!(config_yaml)
  end

  @doc """
  Translates from YAML text representation to map
  """
  @spec yaml_to_map!(String.t()) :: map()
  def yaml_to_map(config_yaml) do
    case YamlElixir.read_from_string(config_yaml) do
      {:ok, x} ->
        case is_map(x) do
          true ->
            {:ok, x}

          false ->
            {:error, %YamlElixir.ParsingError{}}
        end

      # Forward {:error}
      x ->
        x

    end
  end

  @doc """
  Translates pid to String
  """
  def pid_to_string(pid) do
    :erlang.pid_to_list(pid)
    |> to_string
  end

  # Function to find the global name from the PID
  def get_global_name(pid) do
    :global.registered_names()
    |> Enum.find(fn name -> :global.whereis_name(name) == pid end)
  end
end
