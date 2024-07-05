defmodule Cocktailparty.Input.ConnectionTypes do
  @connection_types [
    {"Redis", "redis", Cocktailparty.Input.Redis},
    {"STOMP", "stomp", Cocktailparty.Input.Stomp}
    # Add other connection types here
  ]

  def all, do: Enum.map(@connection_types, fn {name, type, _module} -> {name, type} end)
  def get_module(type), do: Enum.find(@connection_types, fn {_name, t, _module} -> t == type end) |> elem(2)
end
