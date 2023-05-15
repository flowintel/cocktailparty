defmodule CocktailpartyWeb.Admin.UserHTML do
  use CocktailpartyWeb, :html

  alias Cocktailparty.UserManagement.User

  embed_templates "../user_html/*"

  @doc """
  Renders a user form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :roles, :list, required: true

  def user_form(assigns)
end
