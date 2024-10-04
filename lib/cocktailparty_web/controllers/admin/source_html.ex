defmodule CocktailpartyWeb.Admin.SourceHTML do
  use CocktailpartyWeb, :html

  embed_templates "../source_html/*"

  @doc """
  Renders a source form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :connections, :list, required: true
  attr :connection_source_types, :map, required: true
  attr :source_types, :list, required: true

  def source_form(assigns)
end
