defmodule CocktailpartyWeb.Admin.ConnectionController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.Input
  alias Cocktailparty.Input.Connection
  alias Cocktailparty.Input.ConnectionTypes
  import Cocktailparty.Util

  def index(conn, _params) do
    connections = Input.list_connections()
    render(conn, :index, connections: connections)
  end

  def new(conn, _params) do
    changeset = Input.change_connection(%Connection{})
    connection_types = ConnectionTypes.all()
    render(conn, :new, changeset: changeset, connection_types: connection_types)
  end

  def create(conn, %{"connection" => connection_params}) do
    {:ok, config_str} = Map.fetch(connection_params, "config")
    # replace with function from Util
    config = yaml_to_map!(config_str)

    case Input.create_connection(Map.put(connection_params, "config", config)) do
      {:ok, connection} ->
        # TODO: handle errors
        # Cocktailparty.Input.Connection.start(connection)

        conn
        |> put_flash(:info, "Connection created successfully.")
        |> redirect(to: ~p"/admin/connections/#{connection}")

      {:error, %Ecto.Changeset{} = changeset} ->
        txt_config = map_to_yaml!(changeset.changes.config)
        new_changes = Map.put(changeset.changes, :config, txt_config)
        new_changeset = Map.put(changeset, :changes, new_changes)

        connection_types = ConnectionTypes.all()

        render(conn, :new, changeset: new_changeset, connection_types: connection_types)
    end
  end

  def show(conn, %{"id" => id}) do
    connection = Input.get_connection_map!(id)
    render(conn, :show, connection: connection)
  end

  def edit(conn, %{"id" => id}) do
    connection_map = Input.get_connection_map!(id)

    changeset =
      Input.change_connection(connection_map)
      |> Map.put(:data, Input.switch_config_repr!(connection_map))

    connection_types = ConnectionTypes.all()

    render(conn, :edit,
      connection: connection_map,
      changeset: changeset,
      connection_types: connection_types
    )
  end

  def update(conn, %{"id" => id, "connection" => connection_params}) do
    connection = Input.get_connection_text!(id)

    yaml_config = connection_params["config"]

    case YamlElixir.read_from_string(yaml_config) do
      {:ok, config_map} ->
        connection_params = Map.put(connection_params, "config", config_map)

        case Input.update_connection(connection, connection_params) do
          {:ok, connection} ->
            conn
            |> put_flash(:info, "Connection updated successfully.")
            |> redirect(to: ~p"/admin/connections/#{connection}")

          {:error, %Ecto.Changeset{} = changeset} ->
            connection_types = ConnectionTypes.all()

            txt_config = map_to_yaml!(changeset.changes.config)
            new_changes = Map.put(changeset.changes, :config, txt_config)
            new_changeset = Map.put(changeset, :changes, new_changes)

            render(conn, :edit,
              connection: connection,
              changeset: new_changeset,
              connection_types: connection_types
            )
        end

      {:error, reason = %YamlElixir.ParsingError{}} ->
        connection_types = ConnectionTypes.all()

        conn
        |> put_flash(:error, "Failed to parse YAML: #{reason.message}")
        |> render("edit.html",
          connection: connection,
          changeset: Connection.changeset(connection, connection_params),
          connection_types: connection_types
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    connection = Input.get_connection_map!(id)
    {:ok, _connection} = Input.delete_connection(connection)
    Input.Connection.terminate(connection)

    conn
    |> put_flash(:info, "Connection deleted successfully.")
    |> redirect(to: ~p"/admin/connections")
  end
end
