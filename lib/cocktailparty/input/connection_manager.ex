defmodule Cocktailparty.Input.ConnectionManager do
  alias Cocktailparty.Input.ConnectionTypes

  def start_connection(connection = %Cocktailparty.Input.Connection{type: type}) do
    if connection.enabled do
      module = ConnectionTypes.get_module(type)

      if module do
        module.start_link(connection)
      else
        {:error, "Unsupported connection type"}
      end
    end
  end
end
