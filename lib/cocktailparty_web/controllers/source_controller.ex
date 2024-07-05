defmodule CocktailpartyWeb.SourceController do
  use CocktailpartyWeb, :controller

  require Logger

  alias Cocktailparty.Catalog
  import CocktailpartyWeb.AccessControl

  plug :show_source_access_control when action in [:show]
  plug :index_source_access_control when action in [:index]
  # other actions are not exposed

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
    source = Catalog.get_source_text!(id)
    sample = Catalog.get_sample(id)

    source =
      source
      |> Map.put(:subscribed, Catalog.is_subscribed?(source.id, conn.assigns.current_user.id))

    render(conn, :show, source: source, sample: sample)
  end

  def subscribe(conn, %{"source_id" => source_id}) do
    Logger.debug("User #{conn.assigns.current_user.id} subscribing to source #{source_id}")

    case Catalog.subscribe(source_id, conn.assigns.current_user.id) do
      {:ok, _source} ->
        conn
        |> put_flash(:info, "Subscribed to source #{source_id}")
        |> redirect(to: ~p"/sources/#{source_id}")

      {:error, changeset} ->
        conn
        |> put_flash(:error, changeset)
        |> redirect(to: ~p"/sources/#{source_id}")
    end
  end

  def unsubscribe(conn, %{"source_id" => source_id}) do
    Logger.debug("User #{conn.assigns.current_user.id} unsubscribing from source #{source_id}")

    case Catalog.unsubscribe(
           String.to_integer(source_id),
           conn.assigns.current_user.id
         ) do
      {1, _deleted} ->
        conn
        |> put_flash(:info, "Unsubscribed from source #{source_id} ")
        |> redirect(to: ~p"/sources/#{source_id}")

      {0, _deleted} ->
        conn
        |> put_flash(:error, "Unsubscribing from #{source_id} failed.")
        |> redirect(to: ~p"/sources/#{source_id}")
    end
  end
end
