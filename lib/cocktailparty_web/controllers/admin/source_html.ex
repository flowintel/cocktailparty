defmodule CocktailpartyWeb.Admin.SourceHTML do
  use CocktailpartyWeb, :html

  embed_templates "../source_html/*"

  @doc """
  Renders a source form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :redis_instances, :list, required: true

  def source_form(assigns)
end
