defmodule Cocktailparty.SinkCatalog do
  @moduledoc """
  The SinkCatalog context.
  """

  require Logger

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Cocktailparty.UserManagement
  alias Cocktailparty.Input.RedisInstance
  alias Cocktailparty.Repo
  alias Cocktailparty.SinkCatalog.Sink
  alias Cocktailparty.Accounts.User

  # improve this, it also appears in channels/sinkchannel
  @minimim_role "user"

  @doc """
  Returns the list of sinks.

  ## Examples

      iex> list_sinks()
      [%Sink{}, ...]

  """
  def list_sinks do
    Repo.all(Sink)
    |> Repo.preload(:redis_instance)
  end

  @doc """
  Returns the list of sinks / joined with its use

  ## Examples

      iex> list_sinks_with_user()
      [%Sink{}, ...]

  """
  def list_sinks_with_user do
    Repo.all(Sink)
    |> Repo.preload(:redis_instance)
    |> Repo.preload(:user)
  end

  @doc """
  Returns the list of sinks for a redis instance

  ## Examples

      iex> list_redis_instance_sinks(redis_instance_id)
      [%Sink{}, ...]

  """
  def list_redis_instance_sinks(redis_instance_id) do
    Repo.all(
      from s in Sink,
        join: r in RedisInstance,
        on: s.redis_instance_id == r.id,
        where: r.id == ^redis_instance_id,
        preload: [:user]
    )
  end

  @doc """
  Returns the list of sinks for a given user

  ## Examples

      iex> list_sinks(user_id)
      [%Sink{}, ...]

  """
  def list_user_sinks(user_id) do
    Repo.all(from s in Sink, where: s.user_id == ^user_id)
  end

  @doc """
  Gets a single sink.

  Raises if the Sink does not exist or if it does not belong to the current user

  ## Examples

      iex> get_sink(123)
      {:ok, %Sink{}}

      iex> get_sink(1234)
      {:error, "Unauthorized"}

  """
  def get_auth_sink(id, user_id) do
    sink = Repo.get(Sink, id)

    case sink do
      %{user_id: ^user_id} ->
        {:ok, sink}

      _ ->
        {:error, "Unauthorized"}
    end
  end

  @doc """
  Gets a single sink.

  Raises if the Sink does not exist

  ## Examples

      iex> get_sink!(123)
      {:ok, %Sink{}}

      iex> get_sink!(1234)
      ** (Ecto.NoResultsError)

  """
  def get_sink!(id) do
    Repo.get!(Sink, id)
    |> Repo.preload(:user)
    |> Repo.preload(:redis_instance)
  end

  @doc """
  Creates a sink.

  ## Examples

      iex> create_sink(%{field: value})
      {:ok, %Sink{}}

      iex> create_sink(%{field: bad_value})
      {:error, ...}

  """
  def create_sink(attrs \\ %{}, user_id) do
    ri_id = attrs["redis_instance_id"]

    redis_instance =
      case ri_id do
        nil -> Cocktailparty.Input.get_first_default_sink()
        _ -> Cocktailparty.Input.get_redis_instance!(attrs["redis_instance_id"])
      end

    redis_instance
    |> Ecto.build_assoc(:sinks)
    |> change_sink(attrs)
    |> put_change(:user_id, user_id)
    |> Repo.insert()

    # TODO broker magic on insert
  end

  @doc """
  Updates a sink.

  ## Examples

      iex> update_sink(sink, %{field: new_value})
      {:ok, %Sink{}}

      iex> update_sink(sink, %{field: bad_value})
      {:error, ...}

  """
  def update_sink(%Sink{} = sink, attrs) do
    changeset = change_sink(sink, attrs)
    Repo.update(changeset)
  end

  @doc """
  Deletes a Sink.

  ## Examples

      iex> delete_sink(sink)
      {:ok, %Sink{}}

      iex> delete_sink(sink)
      {:error, ...}

  """
  def delete_sink(%Sink{} = sink) do
    Repo.delete(sink)
  end

  @doc """
  Returns a data structure for tracking sink changes.

  ## Examples

      iex> change_sink(sink)
      %Todo{...}

  """
  def change_sink(%Sink{} = sink, attrs \\ %{}) do
    sink
    |> Sink.changeset(attrs)
  end

  def list_authorized_users do
    Repo.all(User)
    |> Enum.filter(fn user -> UserManagement.is_allowed?(user.id, @minimim_role) end)
  end
end
