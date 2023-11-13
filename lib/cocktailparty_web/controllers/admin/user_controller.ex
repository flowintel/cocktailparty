defmodule CocktailpartyWeb.Admin.UserController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.UserManagement
  alias Cocktailparty.Accounts.User
  alias Cocktailparty.Roles
  alias CocktailpartyWeb.Tracker

  require Logger

  def index(conn, _params) do
    users = UserManagement.list_users()
    # List connected user
    connected_users_feeds = Tracker.get_all_connected_users_feeds()
    connected_users_sinks = Tracker.get_all_connected_users_sinks()

    updated_users =
      Enum.reduce(users, [], fn user, updated_users ->
        updated_user =
          user
          |> Map.put(:is_present_feed, Enum.member?(connected_users_feeds, user.id))
          |> Map.put(:is_present_sink, Enum.member?(connected_users_sinks, user.id))

        [updated_user | updated_users]
      end)

    render(conn, :index, users: updated_users)
  end

  def new(conn, _params) do
    changeset = UserManagement.change_user(%User{})
    # render(conn, :new, changeset: changeset, roles: User.roles())
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case UserManagement.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: ~p"/admin/users/#{user}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, roles: Roles.list_roles())
    end
  end

  def show(conn, %{"id" => id}) do
    user = UserManagement.get_user!(id)
    connected_users_feeds = Tracker.get_all_connected_users_feeds()

    user =
      Map.put(user, :is_present_feed, Enum.member?(connected_users_feeds, String.to_integer(id)))

    connected_users_sinks = Tracker.get_all_connected_users_sinks()

    user =
      Map.put(user, :is_present_sink, Enum.member?(connected_users_sinks, String.to_integer(id)))

    render(conn, :show, user: user)
  end

  def edit(conn, %{"id" => id}) do
    user = UserManagement.get_user!(id)
    changeset = UserManagement.change_user(user)
    render(conn, :edit, user: user, changeset: changeset, roles: Roles.list_roles())
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "user" => user_params}) do
    user = UserManagement.get_user!(id)

    case UserManagement.update_user(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User updated successfully.")
        |> redirect(to: ~p"/admin/users/#{user}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, user: user, changeset: changeset, roles: Roles.list_roles())
    end
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    user = UserManagement.get_user!(id)
    {:ok, _user} = UserManagement.delete_user(user)

    conn
    |> put_flash(:info, "User deleted successfully.")
    |> redirect(to: ~p"/admin/users")
  end
end
