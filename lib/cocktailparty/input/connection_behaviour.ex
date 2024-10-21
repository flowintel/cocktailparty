defmodule Cocktailparty.Input.ConnectionBehavior do
  @callback start_link(config :: map) :: {:ok, pid} | {:error, term}
end
