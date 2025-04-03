defmodule CocktailpartyWeb.SinkController do
  use CocktailpartyWeb, :controller

  import Cocktailparty.Util
  alias CocktailpartyWeb.AccessControl
  alias Cocktailparty.SinkCatalog
  alias Cocktailparty.SinkCatalog.Sink
  alias Cocktailparty.SinkCatalog.SinkType
  alias Cocktailparty.Input.ConnectionTypes
  import CocktailpartyWeb.AccessControl

  plug :see_sinks_access_control when action in [:show, :index]
  plug :create_sinks_access_control when action in [:new, :create, :update, :edit, :delete]

  def new(conn, _params) do
    changeset = SinkCatalog.change_sink(%Sink{})

    connection = Cocktailparty.Input.get_default_sink_connection()
    type = ConnectionTypes.get_default_sink_module(connection.type)

    {:ok, required_fields} = SinkType.get_required_fields(connection.type, type)

    render(conn, :new, changeset: changeset, required_fields: required_fields)
  end

  def create(conn, %{"sink" => sink_params}) do
    sink_params =
      sink_params
      |> Map.put("user_id", conn.assigns.current_user.id)

    case SinkCatalog.create_default_sink(sink_params) do
      {:ok, sink} ->
        conn
        |> put_flash(:info, "Sink created successfully.")
        |> redirect(to: ~p"/sinks/#{sink}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    sink = SinkCatalog.get_sink!(id)
    changeset = SinkCatalog.change_sink(sink)

    connection = Cocktailparty.Input.get_default_sink_connection()
    type = ConnectionTypes.get_default_sink_module(connection.type)

    {:ok, required_fields} = SinkType.get_required_fields(connection.type, type)

    # Convert the config map to a YAML string and set it in the changeset
    config_yaml = map_to_yaml!(sink.config)
    changeset = Ecto.Changeset.put_change(changeset, :config_yaml, config_yaml)

    render(conn, :edit, sink: sink, changeset: changeset, required_fields: required_fields)
  end

  def update(conn, %{"id" => id, "sink" => sink_params}) do
    sink = SinkCatalog.get_sink!(id)

    connection = Cocktailparty.Input.get_default_sink_connection()
    type = ConnectionTypes.get_default_sink_module(connection.type)
    {:ok, required_fields} = SinkType.get_required_fields(connection.type, type)

    case SinkCatalog.update_sink(sink, sink_params) do
      {:ok, sink} ->
        conn
        |> put_flash(:info, "Sink updated successfully.")
        |> redirect(to: ~p"/sinks/#{sink}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, sink: sink, changeset: changeset, required_fields: required_fields)
    end
  end

  def index(conn, _params) do
    sinks = SinkCatalog.list_user_sinks(conn.assigns.current_user.id)

    render(conn, :index,
      sinks: sinks,
      can_create: AccessControl.can_create_sink?(conn.assigns.current_user.id)
    )
  end

  def show(conn, %{"id" => id}) do
    sink = SinkCatalog.get_auth_sink(id, conn.assigns.current_user.id)

    case sink do
      {:ok, sink} ->
        sample = SinkCatalog.get_sample(id)
        render(conn, :show, sink: sink, sample: sample)

      {:error, "Unauthorized"} ->
        conn
        |> put_flash(:error, "Unauthorized")
        |> redirect(to: ~p"/sinks")
    end
  end

  def delete(conn, %{"id" => id}) do
    sink = SinkCatalog.get_auth_sink(id, conn.assigns.current_user.id)

    case sink do
      {:ok, sink} ->
        SinkCatalog.delete_sink(sink)

        conn
        |> put_flash(:info, "Sink deleted successfully")
        |> redirect(to: ~p"/sinks")

      {:error, "Unauthorized"} ->
        conn
        |> put_flash(:error, "Unauthorized")
        |> redirect(to: ~p"/sinks")
    end
  end
end
