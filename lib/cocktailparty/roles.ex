defmodule Cocktailparty.Roles do
  @moduledoc """
  The Roles context.
  """

  import Ecto.Query, warn: false
  alias Cocktailparty.Repo

  alias Cocktailparty.Roles.Role
  alias Cocktailparty.Accounts.User

  @doc """
  Returns the list of roles.

  ## Examples

      iex> list_roles()
      [%Role{}, ...]

  |> Repo.
  """
  def list_roles do
    Repo.all(Role)
  end

  @doc """
  Returns the list of user with a specified role.

  ## Examples

      iex> list_users_with_role()
      [%User{}, ...]

  """
  def list_users_with_role(role_id) do
    Repo.all(from u in User, where: u.role_id == ^role_id)
    |> Repo.preload(:role)
  end

  @doc """
  Gets a single role.

  Raises `Ecto.NoResultsError` if the Role does not exist.

  ## Examples

      iex> get_role!(123)
      %Role{}

      iex> get_role!(456)
      ** (Ecto.NoResultsError)

  """
  def get_role!(id), do: Repo.get!(Role, id)

  @doc """
  Creates a role.

  ## Examples

      iex> create_role(%{field: value})
      {:ok, %Role{}}

      iex> create_role(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a role.

  ## Examples

      iex> update_role(role, %{field: new_value})
      {:ok, %Role{}}

      iex> update_role(role, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_role(%Role{} = role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Use a transaction to delete a role and assign the default role the associated users.

  ## Examples

      iex> delete_role(role)
      {:ok, %Role{}}

      iex> delete_role(role)
      {:error, %Ecto.Changeset{}}

  """
  def delete_role(%Role{} = role) do
    # get users associated with this role
    users = list_users_with_role(role.id)
    # release the foreign key constraint by mapping associated users' role to default
    Enum.reduce(users, Ecto.Multi.new(), fn user, acc ->
      # update users
      Ecto.Multi.update(
        acc,
        "update:" <> Integer.to_string(user.id),
        User.changeset(user, %{role_id: get_default_role_id!()})
      )
    end)
    # delete role
    |> Ecto.Multi.delete("delete:" <> Integer.to_string(role.id), role)
    |> Repo.transaction()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking role changes.

  ## Examples

      iex> change_role(role)
      %Ecto.Changeset{data: %Role{}}

  """
  def change_role(%Role{} = role, attrs \\ %{}) do
    Role.changeset(role, attrs)
  end

  @doc """
  Return the default role, raise on error
  ## Examples

      iex> get_default_role!()
      %Role{}

  """
  def get_default_role_id!() do
    Repo.one(from r in Role, where: r.name == "default", select: r.id)
  end
end
