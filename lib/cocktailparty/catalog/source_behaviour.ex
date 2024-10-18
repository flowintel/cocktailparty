defmodule Cocktailparty.Catalog.SourceBase do
  @moduledoc """
  Defines the behavior for sources.
  """

  @callback required_fields() :: [atom()]

  defmacro __using__(_) do
    quote do
      @behaviour Cocktailparty.Catalog.SourceBase

      def required_fields, do: []

      defoverridable required_fields: 0
    end
  end
end
