defmodule CocktailpartyWeb.Admin.RedisInstanceHTML do
  use CocktailpartyWeb, :html

  embed_templates "redis_instance_html/*"

  @doc """
  Renders a redis_instance form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def redis_instance_form(assigns)
end
