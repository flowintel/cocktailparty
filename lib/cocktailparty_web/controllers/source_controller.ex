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

    render(conn, :index, sources: sources)
  end

  def show(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)
    render(conn, :show, source: source)
  end

  def subscribe(conn, params) do
    Logger.debug("Subscribing user #{conn.assigns.current_user.id} to source #{params["id"]}")

    case Catalog.subscribe(params["id"], conn.assigns.current_user.id) do
      {:ok, _source} ->
        conn
        |> put_flash(:info, "Subscribed")
        |> redirect(to: ~p"/sources/#{params["id"]}")

      {:error, changeset} ->
        conn
        |> put_flash(:error, changeset)
        |> redirect(to: ~p"/sources")
    end
  end

  def unsubscribe(conn, params) do
    Logger.debug("Unsubscribing user #{conn.assigns.current_user.id} from source #{params["id"]}")

    case Catalog.unsubscribe(String.to_integer(params["id"]), conn.assigns.current_user.id) do
      {1, _deleted} ->
        conn
        |> put_flash(:info, "Unsubscribed")
        |> redirect(to: ~p"/sources")

      {0, _deleted} ->
        conn
        |> put_flash(:error, "Unsubscribe failed")
        |> redirect(to: ~p"/sources")
    end
  end
end
