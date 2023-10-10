defmodule Cocktailparty.Catalog do
  @moduledoc """
  The Catalog context.
  """
  require Logger

  import Ecto.Query, warn: false
  alias Cocktailparty.Repo

  alias Cocktailparty.Catalog.Source
  alias Cocktailparty.Accounts.User
  alias Cocktailparty.Accounts

  @doc """
  Returns the list of sources.

  ## Examples

      iex> list_sources()
      [%Source{}, ...]

  """
  def list_sources do
    Repo.all(Source)
    |> Repo.preload(:users)
  end

  @doc """
  Gets a single source.

  Raises `Ecto.NoResultsError` if the Source does not exist.

  ## Examples

      iex> get_source!(123)
      %Source{}

      iex> get_source!(456)
      ** (Ecto.NoResultsError)

  """
  def get_source!(id) do
    Repo.get!(Source, id)
    |> Repo.preload(:users)
  end

  @doc """
  Creates a source.

  ## Examples

      iex> create_source(%{field: value})
      {:ok, %Source{}}

      iex> create_source(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_source(attrs \\ %{}) do
    %Source{}
    |> change_source(attrs)
    |> Repo.insert()
    |> case do
      {:ok, source} ->
        _ = notify_broker({:new_source, source})
        {:ok, source}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Updates a source.

  ## Examples

      iex> update_source(source, %{field: new_value})
      {:ok, %Source{}}

      iex> update_source(source, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_source(%Source{} = source, attrs) do
    changeset = change_source(source, attrs)
    # Preserve the existing users association
    changeset = Ecto.Changeset.put_assoc(changeset, :users, source.users)

    case changeset do
      %Ecto.Changeset{
        changes: %{channel: new_channel},
        data: %Source{} = source
      }
      when source.channel != new_channel ->
        # We ask the broker to delete the source with the old channel
        GenServer.cast(Cocktailparty.Broker, {:delete_source, source})

        # We update the source
        {:ok, source} = Repo.update(changeset)

        # And we ask the broker to subscribe to the updated source
        GenServer.cast(
          Cocktailparty.Broker,
          {:new_source, source}
        )

        {:ok, source}

      _ ->
        Repo.update(changeset)
    end
  end

  @doc """
  Deletes a source.

  ## Examples

      iex> delete_source(source)
      {:ok, %Source{}}

      iex> delete_source(source)
      {:error, %Ecto.Changeset{}}

  """
  def delete_source(%Source{} = source) do
    Repo.delete(source)
    |> case do
      {:ok, source} ->
        _ = notify_broker({:delete_source, source})
        {:ok, source}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source changes.

  ## Examples

      iex> change_source(source)
      %Ecto.Changeset{data: %Source{}}

  """
  def change_source(%Source{} = source, attrs \\ %{}) do
    users = list_users_by_id(attrs["user_ids"])

    source
    |> Repo.preload(:users)
    |> Source.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:users, users)
  end

  def list_users_by_id([]), do: []
  def list_users_by_id(nil), do: []

  def list_users_by_id(user_ids) do
    Repo.all(from u in User, where: u.id in ^user_ids)
  end

  def is_subscribed?(source_id, user_id) do
    src = get_source!(source_id)
    user = Accounts.get_user!(user_id)

    if Enum.member?(src.users, user) do
      true
    else
      false
    end
  end

  @doc """
  Subscribes a user to a source
  returns
    {:ok, struct}       -> # Updated with success
    {:error, changeset} -> # Something went wrong

  ## Examples

      iex> subscribe(1,2)
      %Ecto.Changeset{data: %Source{}}

  """
  def subscribe(source_id, user_id) do
    src = get_source!(source_id)
    user = Accounts.get_user!(user_id)
    user_list = src.users |> Enum.concat([user])

    src_chgst = Ecto.Changeset.change(src)
    src_with_user = Ecto.Changeset.put_assoc(src_chgst, :users, user_list)
    Repo.update(src_with_user)
  end

  def unsubscribe(source_id, user_id) do
    # straight forward way
    query =
      from s in "sources_subscriptions",
        where:
          s.source_id == ^source_id and
            s.user_id == ^user_id,
        select: s.id

    Repo.delete_all(query)
  end

  defp notify_broker(msg) do
    GenServer.cast(Cocktailparty.Broker, msg)
  end
end
