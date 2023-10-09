defmodule CocktailpartyWeb.Admin.SinkHTML do
  use CocktailpartyWeb, :html

  embed_templates "sink_html/*"

  @doc """
  Renders an admin sink form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def sink_form(assigns)
end
