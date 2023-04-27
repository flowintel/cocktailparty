defmodule CocktailpartyWeb.Admin.SourceController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.Catalog
  alias Cocktailparty.Catalog.Source

  def index(conn, _params) do
    sources = Catalog.list_sources()
    render(conn, :index, sources: sources, is_admin: true)
  end

  def new(conn, _params) do
    changeset = Catalog.change_source(%Source{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"source" => source_params}) do
    case Catalog.create_source(source_params) do
      {:ok, source} ->
        conn
        |> put_flash(:info, "Source created successfully.")
        |> redirect(to: ~p"/admin/sources/#{source}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)
    render(conn, :show, source: source, is_admin: true)
  end

  def edit(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)
    changeset = Catalog.change_source(source)
    render(conn, :edit, source: source, changeset: changeset)
  end

  def update(conn, %{"id" => id, "source" => source_params}) do
    source = Catalog.get_source!(id)

    case Catalog.update_source(source, source_params) do
      {:ok, source} ->
        conn
        |> put_flash(:info, "Source updated successfully.")
        |> redirect(to: ~p"/admin/sources/#{source}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, source: source, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)
    {:ok, _source} = Catalog.delete_source(source)

    conn
    |> put_flash(:info, "Source deleted successfully.")
    |> redirect(to: ~p"/admin/sources")
  end
end
