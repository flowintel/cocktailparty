defmodule CocktailpartyWeb.Admin.SourceController do
  use CocktailpartyWeb, :controller
  require Logger

  alias Cocktailparty.UserManagement
  alias Cocktailparty.Catalog
  alias Cocktailparty.Catalog.Source
  alias CocktailpartyWeb.Tracker
  alias Cocktailparty.Input

  def index(conn, _params) do
    sources = Catalog.list_sources()
    render(conn, :index, sources: sources)
  end

  def new(conn, _params) do
    changeset = Catalog.change_source(%Source{})
    # get list of redis instances
    instances = Input.list_connections()

    case instances do
      [] ->
        conn
        |> put_flash(:error, "A redis instance is required to create a source.")
        |> redirect(to: ~p"/admin/connections")

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
        instances = Input.list_connections()
        render(conn, :new, changeset: changeset, redis_instances: instances)
    end
  end

  def show(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)

    connected_users = Tracker.get_all_connected_users_feeds()

    updated_users =
      Enum.reduce(source.users, [], fn user, updated_users ->
        updated_user = Map.put(user, :is_present, Enum.member?(connected_users, user.id))
        [updated_user | updated_users]
      end)

    sample = Catalog.get_sample(id)
    source = %{source | users: updated_users}

    # we add edition logic here for the subscribtion modal
    all_users = UserManagement.list_users_short()

    get_src_users =
      Enum.reduce(source.users, [], fn user, acc ->
        acc ++ [%{id: user.id, email: user.email}]
      end)

    potential_subscribers =
      Enum.reduce(all_users, [], fn user, acc ->
        if !Enum.member?(get_src_users, user) do
          acc ++ [user]
        else
          acc
        end
      end)

    changeset = Catalog.change_source(source)

    render(conn, :show,
      source: source,
      sample: sample,
      potential_subscribers: potential_subscribers,
      changeset: changeset
    )
  end

  def edit(conn, %{"id" => id}) do
    source = Catalog.get_source!(id)
    changeset = Catalog.change_source(source)
    # get list of redis instances
    instances = Input.list_connections()

    case instances do
      [] ->
        conn
        |> put_flash(:error, "A redis instance is required to edit a source.")
        |> redirect(to: ~p"/admin/connections")

      _ ->
        render(conn, :edit, source: source, changeset: changeset, redis_instances: instances)
    end
  end

  def update(conn, %{"id" => id, "source" => source_params}) do
    source = Catalog.get_source!(id)
    # get list of redis instances
    instances = Input.list_connections()

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

  def subscribe(conn, %{"source" => %{"user_id" => user_id}, "source_id" => source_id}) do
    Logger.debug("Subscribing user #{user_id} to source #{source_id}")

    case Catalog.subscribe(source_id, user_id) do
      {:ok, _source} ->
        conn
        |> put_flash(:info, "User subscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")

      {:error, changeset} ->
        conn
        |> put_flash(:error, changeset)
        |> redirect(to: ~p"/admin/sources")
    end
  end

  def mass_subscribe(conn, %{"source_id" => source_id}) do
    Logger.debug("Subscribing all potential users to source #{source_id}")

    case Catalog.mass_subscribe(source_id) do
      {:ok, _source} ->
        conn
        |> put_flash(:info, "Users subscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")

      {:error, _} ->
        conn
        |> put_flash(:error, "Users not subscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")
    end
  end

  @spec unsubscribe(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unsubscribe(conn, %{"user_id" => user_id, "source_id" => source_id}) do
    Logger.debug("Unsubscribing user #{user_id} from source #{source_id}")

    case Catalog.unsubscribe(
           String.to_integer(source_id),
           String.to_integer(user_id)
         ) do
      {1, _deleted} ->
        conn
        |> put_flash(:info, "User unsubscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")

      {0, _deleted} ->
        conn
        |> put_flash(:error, "Unsubscribing user failed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")
    end
  end

  def mass_unsubscribe(conn, %{"source_id" => source_id}) do
    Logger.debug("Unsubscribing all users from source #{source_id}")

    case Catalog.mass_unsubscribe(source_id) do
      {number, nil} ->
        conn
        |> put_flash(:info, "#{number} Users unsubscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")

      {:error, _} ->
        conn
        |> put_flash(:error, "Users not unsubscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")
    end
  end
end
