defmodule CocktailpartyWeb.Admin.RoleHTML do
  use CocktailpartyWeb, :html

  embed_templates "role_html/*"

  @doc """
  Renders an admin role form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :permissions_labels, :map, required: true
  attr :action, :string, required: true

  def role_form(assigns)
end
