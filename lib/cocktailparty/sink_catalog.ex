defmodule Cocktailparty.SinkCatalog do
  @moduledoc """
  The SinkCatalog context.
  """

  require Logger

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Cocktailparty.UserManagement
  alias Cocktailparty.Input.Connection
  alias Cocktailparty.Repo
  alias Cocktailparty.SinkCatalog.Sink
  alias Cocktailparty.Accounts.User
  alias CocktailpartyWeb.Endpoint

  @action :create_sinks

  @doc """
  Returns the list of sinks.

  ## Examples

      iex> list_sinks()
      [%Sink{}, ...]

  """
  def list_sinks do
    Repo.all(Sink)
    |> Repo.preload(:connection)
  end

  @doc """
  Returns the list of sinks / joined with its use

  ## Examples

      iex> list_sinks_with_user()
      [%Sink{}, ...]

  """
  def list_sinks_with_user do
    Repo.all(Sink)
    |> Repo.preload(:connection)
    |> Repo.preload(:user)
  end

  @doc """
  Returns the list of sinks for a redis instance

  ## Examples

      iex> list_connection_sinks(connection_id)
      [%Sink{}, ...]

  """
  def list_connection_sinks(connection_id) do
    Repo.all(
      from s in Sink,
        join: r in Connection,
        on: s.connection_id == r.id,
        where: r.id == ^connection_id,
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

      iex> get_auth_sink(123)
      {:ok, %Sink{}}

      iex> get_auth_sink(1234)
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
    |> Repo.preload(:connection)
  end

  @doc """
  Gets a single sink.

  ## Examples

      iex> get_sink(123)
      {:ok, %Sink{}}

      iex> get_sink!(1234)
      {:error, error}

  """
  def get_sink(id) do
    Repo.get(Sink, id)
    |> Repo.preload(:user)
    |> Repo.preload(:connection)
  end

  @doc """
  Creates a sink by admin, all fields are provided

  ## Examples

      iex> create_sink(%{field: value})
      {:ok, %Sink{}}

      iex> create_sink(%{field: bad_value})
      {:error, ...}

  """
  def create_sink(attrs \\ %{}) do
    Cocktailparty.Input.get_connection!(attrs["connection_id"])
    |> Ecto.build_assoc(:sinks)
    |> change_sink(attrs)
    |> Repo.insert()
    |> case do
      {:ok, sink} ->
        notify_monitor({:subscribe, "sink:" <> Integer.to_string(sink.id)})
        {:ok, sink}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Creates a sink by users, no clues about available sinks

  ## Examples

      iex> create_sink(%{field: value}, user_id)
      {:ok, %Sink{}}

      iex> create_sink(%{field: bad_value})
      {:error, ...}

  """
  def create_sink(attrs, user_id) do
    Cocktailparty.Input.get_one_sink_connection()
    |> Ecto.build_assoc(:sinks)
    |> change_sink(attrs)
    |> put_change(:user_id, user_id)
    |> Repo.insert()
    |> case do
      {:ok, sink} ->
        notify_monitor({:subscribe, "sink:" <> Integer.to_string(sink.id)})
        {:ok, sink}

      {:error, msg} ->
        {:error, msg}
    end
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

    case changeset do
      %Ecto.Changeset{
        changes: %{channel: new_channel},
        data: %Sink{} = sink
      }
      when sink.channel != new_channel ->
        # We notify the monitor
        notify_monitor({:unsubscribe, "sink:" <> Integer.to_string(sink.id)})

        # We update the sink
        {:ok, sink} = Repo.update(changeset)

        # And we ask the pubsubmonitor to subscribe to the updated sink
        notify_monitor({:subscribe, "sink:" <> Integer.to_string(sink.id)})

        {:ok, sink}

      _ ->
        Repo.update(changeset)
    end
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
    |> case do
      {:ok, sink} ->
        notify_monitor({:unsubscribe, "sink:" <> Integer.to_string(sink.id)})
        {:ok, sink}

      {:error, msg} ->
        {:error, msg}
    end
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
    |> Enum.filter(fn user -> UserManagement.can?(user.id, @action) end)
  end

  def get_sample(sink_id) when is_binary(sink_id) do
    samples = GenServer.call({:global, Cocktailparty.PubSubMonitor}, {:get, "sink:" <> sink_id})

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

  @doc """
  destroy_sinks_for_users unsubscribe a list of users from all non-public sources
  """
  def destroy_sinks_for_users(users) when is_list(users) do
    # kick users from the sink channels we are about to destroy
    # they won't be able to rejoin without the :create_sinks permission
    Enum.each(users, fn user_id ->
      Endpoint.broadcast("sink:user:" <> Integer.to_string(user_id), "disconnect", %{})
      :ok
    end)

    # we delete the corresponding sinks
    query =
      from s in Sink,
        join: u in User,
        on: s.user_id == u.id,
        where: u.id in ^users

    Repo.all(query)
    |> Enum.each(&delete_sink(&1))
  end

  defp notify_monitor(msg) do
    GenServer.cast({:global, Cocktailparty.PubSubMonitor}, msg)
  end
end
