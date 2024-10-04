defmodule Cocktailparty.Catalog.SourceBase do
  @moduledoc """
  Defines the behavior for sources.
  """

  # @callback start_link(Ecto.Schema.t()) :: GenServer.on_start()
  # @callback init(Ecto.Schema.t()) :: {:ok, any()}
  # @callback required_fields() :: [atom()]


  @callback required_fields() :: [atom()]

  defmacro __using__(_) do
    quote do
      @behaviour Cocktailparty.Catalog.SourceBase

      def required_fields, do: []

      defoverridable required_fields: 0
    end
  end
end
