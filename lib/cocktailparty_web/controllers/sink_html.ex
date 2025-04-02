defmodule CocktailpartyWeb.SinkHTML do
  use CocktailpartyWeb, :html

  embed_templates "sink_html/*"

  @doc """
  Renders a user sink form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :required_fields, :list, required: true

  def sink_form(assigns)
end
