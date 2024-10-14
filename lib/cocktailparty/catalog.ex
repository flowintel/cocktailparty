defmodule Cocktailparty.Catalog do
  @moduledoc """
  The Catalog context.
  """
  require Logger
  import Cocktailparty.Util
  import Ecto.Changeset

  import Ecto.Query, warn: false
  alias Cocktailparty.Input.Connection
  alias Cocktailparty.Input
  alias Cocktailparty.Repo
  alias Cocktailparty.Catalog.{Source, SourceType}
  alias Cocktailparty.Accounts.User
  alias Cocktailparty.Accounts
  alias Cocktailparty.UserManagement
  alias CocktailpartyWeb.Tracker
  alias Cocktailparty.Catalog.SourceManager

  @doc """
  Returns the list of sources.

  ## Examples

      iex> list_sources()
      [%Source{}, ...]

  """
  def list_sources do
    Repo.all(Source)
    |> Repo.preload(:users)
    |> Repo.preload(:connection)
  end

  @doc """
  Returns the list of available source types for a given connection.
  """
  def get_available_source_types(connection_id) do
    connection = Input.get_connection!(connection_id)
    SourceType.get_source_types_for_connection(connection.type)
  end

  @doc """
  Returns the list of non-public sources

  ## Examples

      iex> list_non_public_sources()
      [%Source{}, ...]

  """
  def list_non_public_sources() do
    query_non_public = from s in Source, where: s.public != true
    Repo.all(query_non_public)
  end

  @doc """
  Returns the list of public sources

  ## Examples

      iex> list_public_sources()
      [%Source{}, ...]

  """
  def list_public_sources() do
    query_public = from s in Source, where: s.public == true
    Repo.all(query_public)
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
    |> Repo.preload(:connection)
  end

  @doc """
  Returns the list of sources for a redis instance

  ## Examples

      iex> list_connection_sources(connection_id)
      [%Source{}, ...]

  """
  def list_connection_sources(connection_id) do
    Repo.all(
      from s in Source,
        join: r in Connection,
        on: s.connection_id == r.id,
        where: r.id == ^connection_id
    )
  end

  @doc """
  Gets a single source, with its config as a map

  Raises `Ecto.NoResultsError` if the Source does not exist.

  ## Examples

      iex> get_source!(123)
      %Source{}

      iex> get_source!(456)
      ** (Ecto.NoResultsError)

  """
  def get_source_map!(id) do
    Repo.get!(Source, id)
    |> Repo.preload(:users)
    |> Repo.preload(:connection)
  end

  @doc """
  Gets a single source, with its config as a string

  Raises `Ecto.NoResultsError` if the Source does not exist.

  ## Examples

      iex> get_source!(123)
      %Source{}

      iex> get_source!(456)
      ** (Ecto.NoResultsError)

  """
  def get_source_text!(id) do
    source = Repo.get!(Source, id)

    source
    |> Repo.preload(:users)
    |> Repo.preload(:connection)
    |> Map.put(:config, map_to_yaml!(source.config))
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
    |> Repo.preload(:connection)
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
    Cocktailparty.Input.get_connection_map!(attrs["connection_id"])
    |> Ecto.build_assoc(:sources)
    |> change_source(attrs)
    |> validate_source_type()
    |> Repo.insert()
    |> case do
      {:ok, source} ->
        SourceManager.start_source(source)
        notify_monitor({:subscribe, "feed:" <> Integer.to_string(source.id)})
        {:ok, source}

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp validate_source_type(changeset) do
    connection_id = get_field(changeset, :connection_id)
    source_type = get_field(changeset, :type)

    with %Connection{type: connection_type} <- Input.get_connection!(connection_id),
         source_types <- SourceType.get_source_types_for_connection(connection_type),
         true <- Enum.any?(source_types, fn %{type: type} -> type == source_type end) do
      changeset
    else
      _ -> add_error(changeset, :type, "is not valid for the selected connection type")
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

    if changed?(changeset, :config) do
      source =
        changeset
        |> validate_source_type()

      case Repo.update(source) do
        {:ok, source} ->
          notify_monitor({:unsubscribe, "feed:" <> Integer.to_string(source.id)})
          SourceManager.restart_source(source.id)
          notify_monitor({:subscribe, "feed:" <> Integer.to_string(source.id)})
          {:ok, source}

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      changeset
      |> validate_source_type()
      |> Repo.update()
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
        :ok = SourceManager.stop_source(source.id)
        notify_monitor({:unsubscribe, "feed:" <> Integer.to_string(source.id)})

        # kick users who subscribed to the source
        mass_unsubscribe(Integer.to_string(source.id))

        # kick the rest (users who joined as public source or permission)
        kick_all_users_from_source(source.id)
        {:ok, source}

      {:error, changeset} ->
        {:error, changeset}
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
    src = get_source_map!(source_id)
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
    src = get_source_map!(source_id)
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
    source = get_source_map!(source_id)
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

    kick_users_from_source([user_id], source_id)

    Repo.delete_all(query)
  end

  @spec mass_unsubscribe(binary()) :: any()
  def mass_unsubscribe(source_id) do
    # straight forward way
    query_delete =
      from s in "sources_subscriptions",
        where: s.source_id == ^String.to_integer(source_id)

    query_select =
      from s in "sources_subscriptions",
        where: s.source_id == ^String.to_integer(source_id),
        select: s.user_id

    user_ids = Repo.all(query_select)
    kick_users_from_source(user_ids, String.to_integer(source_id))

    Repo.delete_all(query_delete)
  end

  # TODO remove - it's not used
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
  kick_users_from kicks a list of users from a source
  """
  def kick_users_from_source(user_ids, source_id)
      when is_list(user_ids) and is_integer(source_id) do
    Enum.each(user_ids, fn user_id ->
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

  @doc """
  kick_users_from_public_sources kicks a list of users from all public source
  """
  def kick_users_from_public_sources(user_ids) when is_list(user_ids) do
    public_sources = list_public_sources()

    # we don't query the tracker, we spray kick commands on public sources
    Enum.each(
      public_sources,
      &Enum.each(user_ids, fn user_id ->
        Phoenix.PubSub.broadcast(
          Cocktailparty.PubSub,
          "feed:" <> Integer.to_string(&1.id),
          %Phoenix.Socket.Broadcast{
            topic: "feed:" <> Integer.to_string(&1.id),
            event: :kick,
            payload: user_id
          }
        )

        :ok
      end)
    )
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

  @doc """
  kick_all_users_from_source kicks all users from a source
  """
  def kick_all_users_from_source(source_id) when is_integer(source_id) do
    # query the tracker to get the list of users present on the source's channel
    users_id = Tracker.get_all_connected_users_to_feed(source_id)

    # kick commands
    Enum.each(users_id, fn user_id ->
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
    case GenServer.whereis({:global, "broker_" <> Integer.to_string(source.connection_id)}) do
      {name, node} ->
        # TODO
        Logger.error("TODO: contacting remote broker in  the cluster: #{node}/#{name}")
        {name, node}

      nil ->
        # TODO
        Logger.error(
          "looks like broker_" <>
            Integer.to_string(source.connection_id) <> " is dead - should not happen"
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

  # defp notify_broker(%Source{} = source, msg) do
  #   GenServer.cast(get_broker(source), msg)
  # end

  defp notify_monitor(msg) do
    GenServer.cast({:global, Cocktailparty.PubSubMonitor}, msg)
  end
end
