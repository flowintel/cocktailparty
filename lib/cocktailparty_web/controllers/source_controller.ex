defmodule CocktailpartyWeb.SourceController do
  use CocktailpartyWeb, :controller

  require Logger

  alias Cocktailparty.Catalog

  def index(conn, _params) do
    sources = Catalog.list_sources()
    # Display whether the current user is subscribed to each source
    sources =
      Enum.map(sources, fn source ->
        %{source | users: Catalog.is_subscribed?(source.id, conn.assigns.current_user.id)}
      end)

    render(conn, :index, sources: sources, is_admin: false)
  end

  def subscribe(conn, params) do
    Logger.debug("Subscribing user #{conn.assigns.current_user.id} to source #{params["id"]}")

    case Catalog.subscribe(params["id"], conn.assigns.current_user.id) do
      {:ok, _source} ->
        redirect(conn, to: ~p"/sources")

      {:error, changeset} ->
        conn
        |> put_flash(:error, changeset)
    end
  end

  def unsubscribe(conn, params) do
    Logger.debug("Unsubscribing user #{conn.assigns.current_user.id} from source #{params["id"]}")
    case Catalog.unsubscribe(String.to_integer(params["id"]), conn.assigns.current_user.id) do
      {1, _deleted} ->
        redirect(conn, to: ~p"/sources")

      {0, _deleted} ->
        conn
        |> put_flash(:error, "Unsubscribe failed")
    end
  end
end
