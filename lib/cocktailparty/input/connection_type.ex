defmodule Cocktailparty.Input.ConnectionTypes do
  @connection_types [
    {"Redis", "redis"},
    {"STOMP", "stomp"}
    # Add other connection types here
  ]

  def all, do: @connection_types
end
