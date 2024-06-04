defmodule CocktailpartyWeb.Admin.ConnectionController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.Input
  alias Cocktailparty.Input.Connection

  def index(conn, _params) do
    connections = Input.list_connections()
    render(conn, :index, connections: connections)
  end

  def new(conn, _params) do
    changeset = Input.change_connection(%Connection{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"connection" => connection_params}) do
    case Input.create_connection(connection_params) do
      {:ok, connection} ->
        # TODO: handle errors
        Cocktailparty.Input.Connection.start(connection)

        conn
        |> put_flash(:info, "Connection created successfully.")
        |> redirect(to: ~p"/admin/connections/#{connection}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    connection = Input.get_connection!(id)
    render(conn, :show, connection: connection)
  end

  def edit(conn, %{"id" => id}) do
    connection = Input.get_connection!(id)
    changeset = Input.change_connection(connection)
    render(conn, :edit, connection: connection, changeset: changeset)
  end

  def update(conn, %{"id" => id, "connection" => connection_params}) do
    connection = Input.get_connection!(id)

    case Input.update_connection(connection, connection_params) do
      {:ok, connection} ->
        conn
        |> put_flash(:info, "Connection updated successfully.")
        |> redirect(to: ~p"/admin/connections/#{connection}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, connection: connection, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    connection = Input.get_connection!(id)
    {:ok, _connection} = Input.delete_connection(connection)
    Input.Connection.terminate(connection)

    conn
    |> put_flash(:info, "Connection deleted successfully.")
    |> redirect(to: ~p"/admin/connections")
  end
end
