defmodule Cocktailparty.Input.Connection do
  use Ecto.Schema
  import Ecto.Changeset
  alias Cocktailparty.Input.ConnectionManager

  require Logger

  schema "connections" do
    field :enabled, :boolean, default: false
    field :name, :string
    field :type, :string
    field :config, Cocktailparty.Encrypted.Map
    field :sink, :boolean, default: false

    has_many :sources, Cocktailparty.Catalog.Source
    has_many :sinks, Cocktailparty.SinkCatalog.Sink

    timestamps()
  end

  @doc false
  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:name, :type, :config, :enabled, :sink])
    |> validate_required([:name, :type, :config, :enabled, :sink])
    |> unique_constraint(:name)
    |> validate_config()
  end

  @doc false
  # we don't allow for changing a connection type once created
  def edit_changeset(connection, attrs) do
    connection
    |> cast(attrs, [:name, :config, :enabled, :sink])
    |> validate_required([:name, :config, :enabled, :sink])
    |> unique_constraint(:name)
  end

  defp validate_config(changeset) do
    case get_field(changeset, :type) do
      nil ->
        changeset

      type ->
        case ConnectionManager.validate_config(type, get_field(changeset, :config)) do
          :ok -> changeset
          {:error, reason} -> add_error(changeset, :config, reason)
        end
    end
  end

  @doc """
  Kill processes related to a connection
  TODO

  """
  def terminate(connection = %__MODULE__{}) do
    Logger.info("Terminating processes connection: " <> Integer.to_string(connection.id))
    sup = get_supervisor()

    case GenServer.whereis({:global, {connection.type, connection.id}}) do
      {name, node} ->
        Logger.info("Connection process is located at: #{node}/#{name}")

      nil ->
        nil

      pid ->
        DynamicSupervisor.terminate_child(sup, pid)
    end
  end

  defp get_supervisor() do
    # locate the reponsible broker process
    case GenServer.whereis({:global, Cocktailparty.ConnectionsDynamicSupervisor}) do
      {name, node} ->
        Logger.info("Supervisor is located at: #{node}/#{name}")
        {name, node}

      nil ->
        # TODO
        Logger.error(
          "It looks like the connection dynamic supervisor is dead, it's not looking good."
        )

        nil

      pid ->
        pid
    end
  end
end
