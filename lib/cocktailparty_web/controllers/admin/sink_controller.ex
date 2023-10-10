defmodule CocktailpartyWeb.Admin.SinkController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.SinkCatalog
  alias Cocktailparty.SinkCatalog.Sink

  def index(conn, _params) do
    sinks = SinkCatalog.list_sinks_with_user()
    render(conn, :index, sinks: sinks)
  end

  def new(conn, _params) do
    changeset = SinkCatalog.change_sink(%Sink{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"sink" => sink_params, user_id: user_id}) do
    case SinkCatalog.create_sink(sink_params, user_id) do
      {:ok, sink} ->
        conn
        |> put_flash(:info, "Sink created successfully.")
        |> redirect(to: ~p"/admin/sinks/#{sink}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    sink = SinkCatalog.get_sink!(id)
    render(conn, :show, sink: sink)
  end

  def edit(conn, %{"id" => id}) do
    sink = SinkCatalog.get_sink!(id)
    changeset = SinkCatalog.change_sink(sink)
    render(conn, :edit, sink: sink, changeset: changeset)
  end

  def update(conn, %{"id" => id, "sink" => sink_params}) do
    sink = SinkCatalog.get_sink!(id)

    case SinkCatalog.update_sink(sink, sink_params) do
      {:ok, sink} ->
        conn
        |> put_flash(:info, "Sink updated successfully.")
        |> redirect(to: ~p"/admin/sinks/#{sink}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, sink: sink, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    sink = SinkCatalog.get_sink!(id)

    {:ok, _sink} = SinkCatalog.delete_sink(sink)

    conn
    |> put_flash(:info, "Sink deleted successfully.")
    |> redirect(to: ~p"/admin/sinks")
  end
end
