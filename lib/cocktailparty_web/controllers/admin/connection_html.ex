defmodule CocktailpartyWeb.Admin.ConnectionHTML do
  use CocktailpartyWeb, :html

  embed_templates "connection_html/*"

  @doc """
  Renders a connection form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :connection_types, :list, required: true
  attr :action, :string, required: true

  def connection_form(assigns)
end
