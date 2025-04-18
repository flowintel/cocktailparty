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
  alias Cocktailparty.Input.ConnectionTypes
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
  Return the connection that is defined as default for creating sinks
  """
  def get_default_sink_connection do
    Repo.one(from c in Connection, where: c.sink == true and c.is_default_sink == true)
  end

  @doc """
  Returns whether there are connections configured as sinks, true or false
  """
  def sink_connection? do
    if Repo.one(from c in Connection, where: c.sink == true, select: count("*")) > 0 do
      true
    else
      false
    end
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

  def get_fullduplex!(id) do
    Repo.one(from c in Connection, where: c.id == ^id, select: c.type)
    |> ConnectionTypes.get_full_duplex()
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

  @doc """
  Set connection as default_sink, and unset all the other ones.
  """
  def set_default_sink(connection_id) do
    Repo.transaction(fn ->
      Repo.update_all(Connection, set: [is_default_sink: false])

      # Set the default sink for the selected connection
      connection = Repo.get!(Connection, connection_id)

      connection
      |> Ecto.Changeset.change(is_default_sink: true)
      |> Repo.update!()
    end)
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
      |> validate_full_duplex()
      |> Repo.insert()

    case conn do
      {:ok, struct} ->
        ConnectionManager.start_connection(struct)
        {:ok, struct}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def validate_full_duplex(changeset) do
    if get_change(changeset, :sink) do
      if ConnectionTypes.get_full_duplex(get_field(changeset, :type)) == true do
        changeset
      else
        add_error(
          changeset,
          :sink,
          "This connection type does not support fullduplex connections"
        )
      end
    else
      changeset
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
      connection =
        changeset
        |> validate_full_duplex()

      case Repo.update(connection) do
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
          type when type in ["redis_pub_sub", "redis", "websocket"] ->
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

          "phoenix" ->
            :sys.get_state(pid)
            |> Slipstream.Socket.connected?()

          "certstream" ->
            DynamicSupervisor.count_children(pid) > 0
        end
    end
  end
end
