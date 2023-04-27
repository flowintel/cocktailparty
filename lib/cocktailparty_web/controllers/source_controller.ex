defmodule CocktailpartyWeb.SourceController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.Catalog

  def index(conn, _params) do
    sources = Catalog.list_sources()
    render(conn, :index, sources: sources, is_admin: false)
  end

  def show(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)
    render(conn, :show, source: source, is_admin: false)
  end
end
