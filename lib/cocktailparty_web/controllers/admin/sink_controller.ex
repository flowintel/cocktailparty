defmodule CocktailpartyWeb.Admin.SinkController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.SinkCatalog
  alias Cocktailparty.SinkCatalog.Sink
  alias Cocktailparty.Input

  def index(conn, _params) do
    sinks = SinkCatalog.list_sinks_with_user()
    render(conn, :index, sinks: sinks)
  end

  def new(conn, _params) do
    changeset = SinkCatalog.change_sink(%Sink{})
    # get list of redis instances
    instances = Input.list_sink_redisinstances()
    # get list of users
    users = SinkCatalog.list_authorized_users()

    case instances do
      [] ->
        conn
        |> put_flash(:error, "A receiving redis instance is required to create a sink.")
        |> redirect(to: ~p"/admin/redisinstances")

      _ ->
        render(conn, :new, changeset: changeset, redis_instances: instances, users: users)
    end
  end

  def create(conn, %{"sink" => sink_params}) do
    case SinkCatalog.create_sink(sink_params) do
      {:ok, sink} ->
        conn
        |> put_flash(:info, "Sink created successfully.")
        |> redirect(to: ~p"/admin/sinks/#{sink}")

      {:error, %Ecto.Changeset{} = changeset} ->
        # get list of redis instances
        instances = Input.list_redisinstances()
        # get list of users
        users = SinkCatalog.list_authorized_users()

        render(conn, :new, changeset: changeset, redis_instances: instances, users: users)
    end
  end

  # TODO presence on sinks
  def show(conn, %{"id" => id}) do
    sink = SinkCatalog.get_sink!(id)
    sample = SinkCatalog.get_sample(id)
    render(conn, :show, sink: sink, sample: sample)
  end

  def edit(conn, %{"id" => id}) do
    sink = SinkCatalog.get_sink!(id)
    changeset = SinkCatalog.change_sink(sink)
    # get list of redis instances
    instances = Input.list_sink_redisinstances()
    # get list of users
    users = SinkCatalog.list_authorized_users()

    case instances do
      [] ->
        conn
        |> put_flash(:error, "A receiving redis instance is required to edit a sink.")
        |> redirect(to: ~p"/admin/redisinstances")

      _ ->
        render(conn, :edit,
          sink: sink,
          changeset: changeset,
          redis_instances: instances,
          users: users
        )
    end
  end

  def update(conn, %{"id" => id, "sink" => sink_params}) do
    sink = SinkCatalog.get_sink!(id)

    case SinkCatalog.update_sink(sink, sink_params) do
      {:ok, sink} ->
        conn
        |> put_flash(:info, "Sink updated successfully.")
        |> redirect(to: ~p"/admin/sinks/#{sink}")

      {:error, %Ecto.Changeset{} = changeset} ->
        # get list of redis instances
        instances = Input.list_sink_redisinstances()
        # get list of users
        users = SinkCatalog.list_authorized_users()

        render(conn, :edit,
          sink: sink,
          changeset: changeset,
          redis_instances: instances,
          users: users
        )
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
