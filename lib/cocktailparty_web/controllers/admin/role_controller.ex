defmodule CocktailpartyWeb.Admin.RoleController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.Roles.Permissions
  alias Cocktailparty.Roles
  alias Cocktailparty.Roles.Role

  def index(conn, _params) do
    roles = Roles.list_roles()
    render(conn, :index, roles: roles, permissions_labels: Permissions.get_permissions_labels())
  end

  def new(conn, _params) do
    changeset = Roles.change_role(%Role{})

    render(conn, :new,
      changeset: changeset,
      permissions_labels: Permissions.get_permissions_labels()
    )
  end

  def create(conn, %{"role" => role_params}) do
    case Roles.create_role(role_params) do
      {:ok, role} ->
        conn
        |> put_flash(:info, "Role created successfully.")
        |> redirect(to: ~p"/admin/roles/#{role}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    role = Roles.get_role!(id)
    render(conn, :show, role: role, permissions_labels: Permissions.get_permissions_labels())
  end

  def edit(conn, %{"id" => id}) do
    role = Roles.get_role!(id)
    changeset = Roles.change_role(role)
    permissions_labels = Permissions.get_permissions_labels()
    render(conn, :edit, role: role, changeset: changeset, permissions_labels: permissions_labels)
  end

  def update(conn, %{"id" => id, "role" => role_params}) do
    role = Roles.get_role!(id)

    case Roles.update_role(role, role_params) do
      {:ok, role} ->
        conn
        |> put_flash(:info, "Role updated successfully.")
        |> redirect(to: ~p"/admin/roles/#{role}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, role: role, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    role = Roles.get_role!(id)

    case Roles.delete_role(role) do
      {:ok, _role} ->
        conn
        |> put_flash(:info, "Role deleted successfully.")
        |> redirect(to: ~p"/admin/roles")

      {:error, _role} ->
        conn
        |> put_flash(:info, "Error deleting role.")
        |> redirect(to: ~p"/admin/roles")
    end
  end
end
