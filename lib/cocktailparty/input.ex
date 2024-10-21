defmodule Cocktailparty.Input do
  @moduledoc """
  The Input context.
  """

  import Ecto.Query, warn: false
  import Cocktailparty.Util
  import Ecto.Changeset
  alias Cocktailparty.Catalog.SourceManager
  alias Cocktailparty.Repo

  alias Cocktailparty.Input.Connection
  alias Cocktailparty.Input.ConnectionManager

  @doc """
  Returns the list of connections.

  ## Examples

      iex> list_connections()
      [%Connection{}, ...]

  """
  def list_connections do
    Repo.all(Connection)
    |> Enum.map(fn instance ->
      instance
      |> Map.put(:connected, connected?(instance))
    end)
  end

  @doc """
  Returns the list of enabled connections

  ## Examples

      iex> list_enabled_connections()
      [%Connection{}, ...]

  """
  def list_enabled_connections do
    Repo.all(from c in Connection, where: c.enabled == true)
    |> Enum.map(fn instance ->
      instance
      |> Map.put(:connected, connected?(instance))
    end)
  end

  @doc """
  Returns the list of redis intances that can be used to push data in

  ## Examples

      iex> list_connections()
      [%Connection{}, ...]

  """
  def list_sink_connections do
    Repo.all(from r in Connection, where: r.sink == true)
  end

  @doc """
  Returns the list of redis intances that can be used to push data in

  ## Examples

      iex> list_connections()
      [%Connection{}, ...]

  """
  def get_one_sink_connection do
    Repo.one(from r in Connection, where: r.sink == true)
  end

  @doc """
  Returns the list of connections for feeding a select component

  ## Examples

      iex> list_connections()
      [{"name", 1}]

  """
  def list_connections_for_select do
    Repo.all(from r in "connections", select: {r.name, r.id})
  end

  @doc """
  Gets a single connection -- with config as a text field

  Raises `Ecto.NoResultsError` if the connection does not exist.

  ## Examples

      iex> get_connection!(123)
      %Connection{}

      iex> get_connection!(456)
      ** (Ecto.NoResultsError)

  """
  def get_connection_text!(id) do
    instance = Repo.get!(Connection, id)

    instance
    |> Map.put(:connected, connected?(instance))
    |> Map.put(:config, map_to_yaml!(instance.config))
  end

  @doc """
  Gets a single connection -- with config as a map

  Raises `Ecto.NoResultsError` if the connection does not exist.

  ## Examples

      iex> get_connection!(123)
      %Connection{}

      iex> get_connection!(456)
      ** (Ecto.NoResultsError)

  """
  def get_connection_map!(id) do
    instance = Repo.get!(Connection, id)

    instance
    |> Map.put(:connected, connected?(instance))
  end

  def get_connection!(id) do
    Repo.get!(Connection, id)
    |> Repo.preload(:sources)
  end

  @doc """
  Switch Connection's config representation between YAML string and map
  """
  @spec switch_config_repr!(map() | String.t()) :: map() | String.t()
  def switch_config_repr!(connection) do
    case connection.config do
      %{} ->
        connection
        |> Map.put(:config, map_to_yaml!(connection.config))

      _ ->
        connection
        |> Map.put(:config, yaml_to_map!(connection.config))
    end
  end

  @spec create_connection() :: any()
  @doc """
  Creates a connection.

  ## Examples

      iex> create_connection(%{field: value})
      {:ok, %Connection{}}

      iex> create_connection(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_connection(attrs \\ %{}) do
    conn =
      %Connection{}
      |> Connection.changeset(attrs)
      |> Repo.insert()

    case conn do
      {:ok, struct} ->
        ConnectionManager.start_connection(struct)
        {:ok, struct}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a connection.

  ## Examples

      iex> update_connection(connection, %{field: new_value})
      {:ok, %Connection{}}

      iex> update_connection(connection, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_connection(%Connection{} = connection, attrs) do
    changeset = change_connection(connection, attrs)

    # We restart related processes if needed
    if changed?(changeset, :config) do
      case Repo.update(changeset) do
        {:ok, connection} ->
          Connection.terminate(connection)
          ConnectionManager.start_connection(connection)
          # get the full object
          conn = get_connection!(connection.id)

          Enum.map(conn.sources, fn x ->
            SourceManager.restart_source(x.id)
          end)

          {:ok, connection}

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      Repo.update(changeset)
    end
  end

  @doc """
  Deletes a connection.

  ## Examples

      iex> delete_connection(connection)
      {:ok, %Connection{}}

      iex> delete_connection(connection)
      {:error, %Ecto.Changeset{}}

  """
  def delete_connection(%Connection{} = connection) do
    Repo.delete(connection)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking connection changes.

  ## Examples

      iex> change_connection(connection)
      %Ecto.Changeset{data: %Connection{}}

  """
  def change_connection(%Connection{} = connection, attrs \\ %{}) do
    Connection.changeset(connection, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking connection changes -- without the type

  ## Examples

      iex> change_edit_connection(connection)
      %Ecto.Changeset{data: %Connection{}}

  """
  def change_edit_connection(%Connection{} = connection, attrs \\ %{}) do
    Connection.edit_changeset(connection, attrs)
  end

  @doc """
  Get the status of a redis connection

  """
  def connected?(%Connection{} = connection) do
    case GenServer.whereis({:global, {connection.type, connection.id}}) do
      nil ->
        false

      # name, node
      {_, _} ->
        true

      # pid
      pid ->
        case connection.type do
          # Redix process exposes a :connected field
          type when type in ["redis_pub_sub", "redis"] ->
            case :sys.get_state(pid) do
              {:connected, _} ->
                true

              _ ->
                false
            end

          # For STOMP, we get the status from the network process
          "stomp" ->
            state =
              :sys.get_state(pid).network_pid
              |> :sys.get_state()

            case state do
              %{is_connected: true} ->
                true

              _ ->
                false
            end
        end
    end
  end
end
