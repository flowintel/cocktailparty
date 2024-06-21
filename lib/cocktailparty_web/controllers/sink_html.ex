defmodule CocktailpartyWeb.SinkHTML do
  use CocktailpartyWeb, :html

  embed_templates "sink_html/*"

  @doc """
  Renders a sink form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :connections, :list, required: true

  def sink_form(assigns)
end
