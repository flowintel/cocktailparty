defmodule CocktailpartyWeb.SourceHTML do
  use CocktailpartyWeb, :html

  # import Phoenix.HTML.Form

  embed_templates "source_html/*", only: ~w(index)

  @doc """
  Renders a source form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def source_form(assigns)
end
