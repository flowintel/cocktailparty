defmodule CocktailpartyWeb.SourceHTML do
  use CocktailpartyWeb, :html

  embed_templates "source_html/*", only: ~w(index show)

  @doc """
  Renders a source form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def source_form(assigns)
end
