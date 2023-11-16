defmodule CocktailpartyWeb.SourceController do
  use CocktailpartyWeb, :controller

  require Logger

  alias Cocktailparty.Catalog
  alias Cocktailparty.UserManagement

  def index(conn, _params) do
    if UserManagement.is_confirmed?(conn.assigns.current_user.id) do
      sources = Catalog.list_sources(conn.assigns.current_user.id)
      # Display whether the current user is subscribed to each source
      sources =
        Enum.map(sources, fn source ->
          %{source | users: Catalog.is_subscribed?(source.id, conn.assigns.current_user.id)}
        end)

      render(conn, :index, sources: sources)
    else
      conn
      |> put_flash(:error, "Your account needs to be confirmed by an admin.")
      |> redirect(to: ~p"/")
    end
  end

  def show(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)
    sample = Catalog.get_sample(id)
    render(conn, :show, source: source, sample: sample)
  end
end
