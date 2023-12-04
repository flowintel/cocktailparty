defmodule Cocktailparty.UserManagement do
  @moduledoc """
  The UserManagement context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Ecto.Multi
  alias Cocktailparty.SinkCatalog.Sink
  alias Cocktailparty.Repo
  alias Cocktailparty.Catalog
  alias Cocktailparty.Roles
  alias Cocktailparty.Roles.Permissions

  require Logger

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
    |> Repo.preload(:role)
  end

  @doc """
  Returns the list of users shortened to name / id

  ## Examples

      iex> list_users()
      [%User{id: 1, name: "asdfa"}, ...]

  """
  def list_users_short do
    Repo.all(from u in User, select: %{id: u.id, email: u.email})
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
    |> Repo.preload(:sinks)
    |> Repo.preload(:role)
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
    |> Repo.preload(:sinks)
    |> Repo.preload(:role)
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
  Updates a user and checks whether its permissions has changed, in which case
  we use the corresponding permission callback to act accordingly.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, ...}

  """

  def update_user(%User{} = user, attrs) do
    # keep track of present role
    original_role_id = user.role_id

    # build the user changeset
    changeset = change_user(user, attrs)

    # if the user's role changed, we trigger the corresponding callbacks:
    # to know witch permissions changed between roles, we create a changeset
    if Map.has_key?(changeset.changes, :role_id) do
      Logger.info("Role changed for #{user.id}, triggering permission callbacks.")
      # let's get the original role
      original_role = Roles.get_role!(original_role_id)
      # get the new_role from the changeset
      new_role = Roles.get_role!(Map.get(changeset.changes, :role_id))

      # create a changeset from the new_role's permissions
      changeset_or =
        Roles.change_role(original_role, %{
          "permissions" => Map.from_struct(new_role.permissions)
        })

      # rumble
      if Map.has_key?(changeset_or.changes, :permissions) do
        Enum.each(changeset_or.changes.permissions.changes, fn x ->
          case x do
            {permission, false} ->
              if function_exported?(Permissions, permission, 2) do
                apply(Permissions, permission, ["demotion", [user.id]])
              end

            {permission, true} ->
              if function_exported?(Permissions, permission, 2) do
                apply(Permissions, permission, ["promotion", [user.id]])
              end
          end
        end)
      end
    end

    changeset
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
  Deletes and kick a User from the system.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, ...}

  """
  def delete_user(%User{} = user) do
    query =
      from s in "sources_subscriptions",
        where: s.user_id == ^user.id,
        select: s.id

    source_list = Repo.all(query)

    Enum.each(source_list, &Catalog.kick_users_from_source([user.id], &1))
    Catalog.kick_users_from_public_sources([user.id])

    Multi.new()
    |> Multi.delete_all("subscriptions:delete:user" <> Integer.to_string(user.id), query)
    |> Multi.delete("user:delete:" <> Integer.to_string(user.id), user)
    |> Repo.transaction()
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
        if user.role.name != "default" do
          true
        else
          false
        end
    end
  end

  @doc """
  check whether a user has a given permission
  return true if the user is_admin, unless the
  permission does not exist
  """
  def can?(user_id, action) do
    user = get_user!(user_id)

    case Map.fetch(user.role.permissions, action) do
      {:ok, true} ->
        true

      # an admin can perform any actions unless it does not exist
      {:ok, false} ->
        false || user.is_admin

      :error ->
        false

      _ ->
        false
    end
  end

  @doc """
  Check whether a user has access right to a sink?
  """
  def has_access_to_sink?(user_id, sink_id) do
    query =
      from s in Sink,
        where: s.user_id == ^user_id,
        where: s.id == ^sink_id,
        select: s.id

    case Repo.all(query) do
      [] ->
        false

      _ ->
        true
    end
  end
end
