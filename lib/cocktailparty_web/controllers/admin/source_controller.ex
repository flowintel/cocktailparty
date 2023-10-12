defmodule CocktailpartyWeb.Admin.SourceController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.Catalog
  alias Cocktailparty.Catalog.Source
  alias CocktailpartyWeb.Presence
  alias Cocktailparty.Input

  def index(conn, _params) do
    sources = Catalog.list_sources()
    render(conn, :index, sources: sources)
  end

  def new(conn, _params) do
    changeset = Catalog.change_source(%Source{})
    # get list of redis instances
    instances = Input.list_redisinstances()

    case instances do
      [] ->
        conn
        |> put_flash(:error, "A redis instance is required to create a source.")
        |> redirect(to: ~p"/admin/redisinstances")

      _ ->
        render(conn, :new, changeset: changeset, redis_instances: instances)
    end
  end

  def create(conn, %{"source" => source_params}) do
    case Catalog.create_source(source_params) do
      {:ok, source} ->
        conn
        |> put_flash(:info, "Source created successfully.")
        |> redirect(to: ~p"/admin/sources/#{source}")

      {:error, %Ecto.Changeset{} = changeset} ->
        # get list of redis instances
        instances = Input.list_redisinstances()
        render(conn, :new, changeset: changeset, redis_instances: instances)
    end
  end

  def show(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)

    connected_users = Presence.get_all_connected_users()

    updated_users =
      Enum.reduce(source.users, [], fn user, updated_users ->
        updated_user = Map.put(user, :is_present, Enum.member?(connected_users, user.id))
        [updated_user | updated_users]
      end)

    source = %{source | users: updated_users}

    render(conn, :show, source: source)
  end

  def edit(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)
    changeset = Catalog.change_source(source)
    # get list of redis instances
    instances = Input.list_redisinstances()

    case instances do
      [] ->
        conn
        |> put_flash(:error, "A redis instance is required to create a source.")
        |> redirect(to: ~p"/admin/redisinstances")

      _ ->
        render(conn, :edit, source: source, changeset: changeset, redis_instances: instances)
    end
  end

  def update(conn, %{"id" => id, "source" => source_params}) do
    source = Catalog.get_source!(id)
    # get list of redis instances
    instances = Input.list_redisinstances()

    case Catalog.update_source(source, source_params) do
      {:ok, source} ->
        conn
        |> put_flash(:info, "Source updated successfully.")
        |> redirect(to: ~p"/admin/sources/#{source}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, source: source, changeset: changeset, redis_instances: instances)
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
