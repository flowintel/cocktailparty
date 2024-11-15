defmodule Cocktailparty.SinkCatalog.SinkBehaviour do
  @moduledoc """
  Defines the behavior that all sink modules must implement.
  """

  @callback required_fields() :: [atom()]
  @doc"""
    Takes a sink process PID and a message (of any type) and returns :ok or an error tuple.
  """
  @callback publish(pid(), term()) :: :ok | {:error, term()}

  defmacro __using__(_) do
    quote do
      @behaviour Cocktailparty.SinkCatalog.SinkBehaviour

      def required_fields, do: []

      defoverridable required_fields: 0
    end
  end
end
