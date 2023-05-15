defmodule CocktailpartyWeb.Admin.UserController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.UserManagement
  alias Cocktailparty.UserManagement.User

  def index(conn, _params) do
    users = UserManagement.list_users()
    render(conn, :index, users: users)
  end

  def new(conn, _params) do
    changeset = UserManagement.change_user(%User{})
    render(conn, :new, changeset: changeset, roles: User.roles())
  end

  def create(conn, %{"user" => user_params}) do
    case UserManagement.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: ~p"/admin/users/#{user}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, roles: User.roles())
    end
  end

  def show(conn, %{"id" => id}) do
    user = UserManagement.get_user!(id)
    render(conn, :show, user: user)
  end

  def edit(conn, %{"id" => id}) do
    user = UserManagement.get_user!(id)
    changeset = UserManagement.change_user(user)
    render(conn, :edit, user: user, changeset: changeset, roles: User.roles())
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = UserManagement.get_user!(id)

    case UserManagement.update_user(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User updated successfully.")
        |> redirect(to: ~p"/admin/users/#{user}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, user: user, changeset: changeset, roles: User.roles())
    end
  end

  def delete(conn, %{"id" => id}) do
    user = UserManagement.get_user!(id)
    {:ok, _user} = UserManagement.delete_user(user)

    conn
    |> put_flash(:info, "User deleted successfully.")
    |> redirect(to: ~p"/admin/users")
  end
end
