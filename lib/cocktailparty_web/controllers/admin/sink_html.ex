defmodule CocktailpartyWeb.Admin.SinkHTML do
  use CocktailpartyWeb, :html

  embed_templates "sink_html/*"

  @doc """
  Renders an admin sink form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :connections, :list, required: true
  attr :connection_sink_types, :map, required: true
  attr :sink_types, :list, required: true
  attr :users, :list, required: true

  def sink_form(assigns)
end
