defmodule CocktailpartyWeb.SourceController do
  use CocktailpartyWeb, :controller

  require Logger

  alias Cocktailparty.Catalog
  import CocktailpartyWeb.AccessControl

  plug :show_source_access_control when action in [:show]
  plug :index_source_access_control when action in [:index]
  # plug :source_access_control when action == :index

  def index(conn, _params) do
    sources = Catalog.list_sources(conn.assigns.current_user.id)
    # Display whether the current user is subscribed to each source
    sources =
      Enum.map(sources, fn source ->
        %{source | users: Catalog.is_subscribed?(source.id, conn.assigns.current_user.id)}
      end)

    render(conn, :index, sources: sources)
  end

  def show(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)
    sample = Catalog.get_sample(id)
    render(conn, :show, source: source, sample: sample)
  end
end
