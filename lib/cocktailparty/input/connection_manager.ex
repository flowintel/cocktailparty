defmodule Cocktailparty.Input.ConnectionManager do
  alias Cocktailparty.Input.ConnectionTypes

  def validate_config(type, config) do
    module = ConnectionTypes.get_module(type)

    if module do
      module.validate_config(config)
    else
      {:error, "Unsupported connection type"}
    end
  end

  def start_connection(%Cocktailparty.Input.Connection{type: type, config: config}) do
    module = ConnectionTypes.get_module(type)

    if module do
      module.start_link(config)
    else
      {:error, "Unsupported connection type"}
    end
  end
end
