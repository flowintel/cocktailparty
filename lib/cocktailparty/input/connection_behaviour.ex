defmodule Cocktailparty.Input.ConnectionBehavior do
  @callback start_link(config :: map) :: {:ok, pid} | {:error, term}
  @callback validate_config(config :: map) :: :ok | {:error, String.t()}
end
