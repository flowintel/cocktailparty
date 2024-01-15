defmodule CocktailpartyWeb.SinkController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.SinkCatalog
  alias Cocktailparty.SinkCatalog.Sink
  alias Cocktailparty.Input
  import CocktailpartyWeb.AccessControl

  plug :sink_access_control when action in [:new, :create, :index, :update, :delete]
  # :show and :edit access control is the controller to avoid duplicating DB request

  def index(conn, _params) do
    sinks = SinkCatalog.list_user_sinks(conn.assigns.current_user.id)
    render(conn, :index, sinks: sinks)
  end

  def new(conn, _params) do
    changeset = SinkCatalog.change_sink(%Sink{})
    # get a receiving redis instance
    instance = Input.get_one_sink_redisinstance()
    case instance do
      nil ->

        conn
        |> put_flash(:error, "A receiving redis instance is required to create a sink.")
        |> redirect(to: ~p"/")

      _ ->
        render(conn, :new, changeset: changeset)
    end
  end

  def create(conn, %{"sink" => sink_params}) do
    case SinkCatalog.create_sink(sink_params, conn.assigns.current_user.id) do
      {:ok, sink} ->
        conn
        |> put_flash(:info, "Sink created successfully.")
        |> redirect(to: ~p"/sinks/#{sink}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
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

  def edit(conn, %{"id" => id}) do
    sink = SinkCatalog.get_auth_sink(id, conn.assigns.current_user.id)

    case sink do
      {:ok, sink} ->
        changeset = SinkCatalog.change_sink(sink)
        render(conn, :edit, sink: sink, changeset: changeset)

      {:error, "Unauthorized"} ->
        conn
        |> put_flash(:error, "Unauthorized")
        |> redirect(to: ~p"/sinks")
    end
  end

  def update(conn, %{"id" => id, "sink" => sink_params}) do
    sink = SinkCatalog.get_auth_sink(id, conn.assigns.current_user.id)

    case sink do
      {:ok, sink} ->
        case SinkCatalog.update_sink(sink, sink_params) do
          {:ok, sink} ->
            conn
            |> put_flash(:info, "Sink updated successfully.")
            |> redirect(to: ~p"/sinks/#{sink}")

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, :edit, sink: sink, changeset: changeset)
        end

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
        {:ok, _sink} = SinkCatalog.delete_sink(sink)

        conn
        |> put_flash(:info, "Sink deleted successfully.")
        |> redirect(to: ~p"/sinks")

      {:error, "Unauthorized"} ->
        conn
        |> put_flash(:error, "Unauthorized")
        |> redirect(to: ~p"/sinks")
    end
  end
end
