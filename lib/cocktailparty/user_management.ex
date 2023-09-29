defmodule Cocktailparty.UserManagement do
  @moduledoc """
  The UserManagement context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Cocktailparty.Repo

  # we reuse Accounts.User schema
  alias Cocktailparty.Accounts.User

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
    |> Repo.preload(:sources)
  end

  @doc """
  Gets a single user.

  Returns nil if the User does not exist


  ## Examples

      iex> get_user!(123)
      %User{}

  """
  def get_user(id) do
    Repo.get(User, id)
    |> Repo.preload(:sources)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, ...}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
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
    user
    |> change_user(attrs)
    |> validate_email_if_set()
    |> validate_password_if_set()
    |> Repo.update()
  end

  def validate_email_if_set(changeset, opts \\ []) do
    case changed?(changeset, :email) do
      false ->
        changeset

      true ->
        User.validate_email(changeset, opts)
    end
  end

  def validate_password_if_set(changeset, opts \\ []) do
    case changed?(changeset, :password) do
      false ->
        changeset

      true ->
        User.validate_password(changeset, opts)
    end
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
    # TODO make this a transaction
    query =
      from s in "sources_subscriptions",
        where: s.user_id == ^user.id,
        select: s.id

    Repo.delete_all(query)

    Repo.delete(user)
    |> case do
      {:ok, user} ->
        {:ok, user}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Returns a data structure for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Todo{...}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    # all change go through this
    changeset = User.changeset(user, attrs)
    # I add the password change if it is present
    case attrs["password"] do
      nil ->
        changeset

      "" ->
        changeset

      _ ->
        put_change(changeset, :password, attrs["password"])
    end
  end

  @doc """
  Check whether a user has been confirmed by an admin
  """
  def is_confirmed?(user_id) do
    user = get_user(user_id)

    case user do
      nil ->
        false

      _ ->
        if Enum.member?(User.roles(), user.role) do
          true
        else
          false
        end
    end
  end
end
