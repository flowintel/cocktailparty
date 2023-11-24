defmodule Cocktailparty.Catalog do
  @moduledoc """
  The Catalog context.
  """
  require Logger

  import Ecto.Query, warn: false
  alias Cocktailparty.Input.RedisInstance
  alias Cocktailparty.Repo
  alias Cocktailparty.Catalog.Source
  alias Cocktailparty.Accounts.User
  alias Cocktailparty.Accounts
  alias Cocktailparty.UserManagement
  alias CocktailpartyWeb.Tracker

  @doc """
  Returns the list of sources.

  ## Examples

      iex> list_sources()
      [%Source{}, ...]

  """
  def list_sources do
    Repo.all(Source)
    |> Repo.preload(:users)
    |> Repo.preload(:redis_instance)
  end

  @doc """
  Returns the list of non-public sources

  ## Examples

      iex> list__non_public_sources()
      [%Source{}, ...]

  """
  def list_non_public_sources() do
    query_non_public = from s in Source, where: s.public != true
    Repo.all(query_non_public)
  end

  @doc """
  Returns the list of sources for a user:
  - admin can list all sources,
  - can :list_all_sources and :access_all_sources can list all sources,
  - everyone can list public sources,
  - users can list sources they are subscribed to.

  ## Examples

      iex> list_sources(1)
      [%Source{}, ...]

  """
  def list_sources(user_id) do
    user = UserManagement.get_user!(user_id)

    query_public = from s in Source, where: s.public == true

    query =
      if user.is_admin || UserManagement.can?(user_id, :list_all_sources) ||
           UserManagement.can?(user_id, :access_all_sources) do
        from(s in Source)
      else
        from s in Source,
          join: u in assoc(s, :users),
          where: u.id == ^user_id,
          union: ^query_public
      end

    Repo.all(query)
    |> Repo.preload(:users)
    |> Repo.preload(:redis_instance)
  end

  @doc """
  Returns the list of sources for a redis instance

  ## Examples

      iex> list_redis_instance_sources(redis_instance_id)
      [%Source{}, ...]

  """
  def list_redis_instance_sources(redis_instance_id) do
    Repo.all(
      from s in Source,
        join: r in RedisInstance,
        on: s.redis_instance_id == r.id,
        where: r.id == ^redis_instance_id
    )
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
    |> Repo.preload(:redis_instance)
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
    Cocktailparty.Input.get_redis_instance!(attrs["redis_instance_id"])
    |> Ecto.build_assoc(:sources)
    |> change_source(attrs)
    |> Repo.insert()
    |> case do
      {:ok, source} ->
        _ = notify_broker(source, {:new_source, source})
        notify_monitor({:subscribe, "feed:" <> Integer.to_string(source.id)})
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
        notify_broker(source, {:delete_source, source})
        # We notify the monitor
        notify_monitor({:unsubscribe, "feed:" <> Integer.to_string(source.id)})

        # We update the source
        {:ok, source} = Repo.update(changeset)

        # And we ask the broker and the pubsubmonitor to subscribe to the updated source
        notify_broker(source, {:new_source, source})
        notify_monitor({:subscribe, "feed:" <> Integer.to_string(source.id)})

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
        _ = notify_broker(source, {:delete_source, source})
        notify_monitor({:unsubscribe, "feed:" <> Integer.to_string(source.id)})
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

  @doc """
  Subscribes a list of users to a source
  returns
    {:ok, struct}       -> # Updated with success
    {:error, changeset} -> # Something went wrong

  ## Examples

      iex> mass_subscribe(1, [1,2,3])
      %Ecto.Changeset{data: %Source{}}

  """
  def mass_subscribe(source_id) do
    source = get_source!(source_id)
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

    user_list =
      Enum.reduce(potential_subscribers, source.users, fn user, acc ->
        u = Accounts.get_user!(user.id)
        acc ++ [u]
      end)

    src_chgst = Ecto.Changeset.change(source)
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

  def mass_unsubscribe(source_id) do
    # straight forward way
    query =
      from s in "sources_subscriptions",
        where: s.source_id == ^String.to_integer(source_id)

    # TODO kick them all from the channel

    Repo.delete_all(query)
  end

  @doc """
  unsubscribe_nonpublic unsubscribe a list of users from all non-public sources
  """
  def unsubscribe_nonpublic(users) when is_list(users) do
    query =
      from ss in "sources_subscriptions",
        join: s in Source,
        on: ss.source_id == s.id,
        where:
          s.public == false and
            ss.user_id in ^users

    query_get =
      from ss in query,
        select: {ss.user_id, ss.source_id}

    query_delete =
      from ss in query,
        select: ss.id

    Repo.all(query_get)
    |> Enum.each(fn {user_id, source_id} ->
      # kick them from the associated channels
      Phoenix.PubSub.broadcast(
        Cocktailparty.PubSub,
        "feed:" <> Integer.to_string(source_id),
        %Phoenix.Socket.Broadcast{
          topic: "feed:" <> Integer.to_string(source_id),
          event: :kick,
          payload: user_id
        }
      )

      :ok
    end)

    Repo.delete_all(query_delete)
  end

  @doc """
  kick_non_subscribed kick a list of users from all non public sources

  """
  def kick_non_subscribed(users) when is_list(users) do
    # Get a list of users subscriptions
    query =
      from ss in "sources_subscriptions",
        join: s in Source,
        on: ss.source_id == s.id,
        where: ss.user_id in ^users,
        select: {ss.user_id, ss.source_id}

    subs = Repo.all(query)

    # Get the list of connections with restricted access to which
    # users currently connected to
    connected_users = Tracker.get_all_connected_users_to_private_feeds()
    illegitimate_connection = Enum.filter(connected_users, fn x -> !Enum.member?(subs, x) end)

    illegitimate_connection
    |> Enum.each(fn %{"source_id" => source_id, "user_id" => user_id} ->
      # kick them from the associated channels
      Phoenix.PubSub.broadcast(
        Cocktailparty.PubSub,
        "feed:" <> Integer.to_string(source_id),
        %Phoenix.Socket.Broadcast{
          topic: "feed:" <> Integer.to_string(source_id),
          event: :kick,
          payload: user_id
        }
      )

      :ok
    end)
  end

  def get_sample(source_id) when is_binary(source_id) do
    samples = GenServer.call({:global, Cocktailparty.PubSubMonitor}, {:get, "feed:" <> source_id})

    case samples do
      [] ->
        []

      _ ->
        Enum.reduce(samples, [], fn sample, acc ->
          case Jason.encode(sample.payload, escape: :html_safe) do
            {:ok, string} ->
              acc ++ [string]

            {:error, _} ->
              [acc]
          end
        end)
    end
  end

  def get_broker(%Source{} = source) do
    # locate the reponsible broker process
    case GenServer.whereis(
           {:global, {:name, "broker_" <> Integer.to_string(source.redis_instance_id)}}
         ) do
      {name, node} ->
        # TODO
        Logger.error("TODO: contacting remote broker in  the cluster: #{node}/#{name}")
        {name, node}

      nil ->
        # TODO
        Logger.error(
          "looks like broker_" <>
            Integer.to_string(source.redis_instance_id) <> " is dead - should not happen"
        )

        nil

      pid ->
        pid
    end
  end

  @doc """
  returns true if a feed is public
  """
  def is_public?(feed_id) when is_bitstring(feed_id) do
    source_id = String.trim_leading(feed_id, "feed:")

    query =
      from s in Source,
        where: s.id == ^source_id,
        select: s.public

    Repo.one(query)
  end

  # Check whether a used is authorized to :show a source
  def authorized_show?(source_id, user_id) do
    Logger.info("Checking authorization for UserID: #{user_id} @ FeedId: #{source_id}.")

    (UserManagement.is_confirmed?(user_id) && is_subscribed?(source_id, user_id)) ||
      (UserManagement.is_confirmed?(user_id) && UserManagement.can?(user_id, :access_all_sources) &&
         UserManagement.can?(user_id, :list_all_sources)) ||
      (UserManagement.is_confirmed?(user_id) && is_public?(source_id))
  end

  defp notify_broker(%Source{} = source, msg) do
    GenServer.cast(get_broker(source), msg)
  end

  defp notify_monitor(msg) do
    GenServer.cast({:global, Cocktailparty.PubSubMonitor}, msg)
  end
end
