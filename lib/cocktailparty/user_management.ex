defmodule Cocktailparty.UserManagement do
  @moduledoc """
  The UserManagement context.
  """

  import Ecto.Query, warn: false
  alias Cocktailparty.Repo

  # we reuse Accounts.User schema
  alias Cocktailparty.UserManagement.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

  """
  def get_user!(id) do
    Repo.get!(User, id)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, ...}

  """
  def create_user(attrs \\ %User{}) do
    %User{}
    |>change_user(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, ...}

  """

  def update_user(%User{} = user, attrs) do
    changeset = change_user(user, attrs)

    changeset
    |> Repo.update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, ...}

  """
  def delete_user(%User{} = user) do
    IO.inspect(user)
    raise "TODO"
  end

  @doc """
  Returns a data structure for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Todo{...}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    user
    |> User.changeset(attrs)
  end
end
