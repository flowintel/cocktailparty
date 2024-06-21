defmodule Cocktailparty.Input do
  @moduledoc """
  The Input context.
  """

  import Ecto.Query, warn: false
  # import Ecto.Changeset
  alias Cocktailparty.Repo

  alias Cocktailparty.Input.Connection

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
    |> Map.put(:config, config_to_yaml(instance.config))
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

  def config_to_yaml(config) do
    Ymlr.document!(config)
  end

  @doc """
  Creates a connection.

  ## Examples

      iex> create_connection(%{field: value})
      {:ok, %Connection{}}

      iex> create_connection(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_connection(attrs \\ %{}) do
    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
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
    # TODO: check enabled
    # TODO check within the map
    # if changed?(changeset, :hostname) or changed?(changeset, :port) do
    #   Connection.terminate(connection)
    #   {:ok, connection} = Repo.update(changeset)
    #   Connection.start(connection)
    #   {:ok, connection}
    # else
    Repo.update(changeset)
    # end
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
  Get the status of a redis connection

  """
  # def connected?(%Connection{} = connection) do
  def connected?(%Connection{} = _) do
    # TODO refacto for connections
    #   case GenServer.whereis({:global, "redix_" <> Integer.to_string(connection.id)}) do
    #     nil ->
    #       false

    #     # name, node
    #     {_, _} ->
    #       true

    #     # pid
    #     pid ->
    #       case :sys.get_state(pid) do
    #         {:connected, _} ->
    #           true

    #         _ ->
    #           false
    #       end
    #   end
    false
  end
end
