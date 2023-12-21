defmodule CocktailpartyWeb.Admin.RedisInstanceController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.Input
  alias Cocktailparty.Input.RedisInstance

  def index(conn, _params) do
    redisinstances = Input.list_redisinstances()
    render(conn, :index, redisinstances: redisinstances)
  end

  def new(conn, _params) do
    changeset = Input.change_redis_instance(%RedisInstance{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"redis_instance" => redis_instance_params}) do
    case Input.create_redis_instance(redis_instance_params) do
      {:ok, redis_instance} ->
        # TODO: handle errors
        Cocktailparty.Input.RedisInstance.start(redis_instance)

        conn
        |> put_flash(:info, "Redis instance created successfully.")
        |> redirect(to: ~p"/admin/redisinstances/#{redis_instance}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    redis_instance = Input.get_redis_instance!(id)
    render(conn, :show, redis_instance: redis_instance)
  end

  def edit(conn, %{"id" => id}) do
    redis_instance = Input.get_redis_instance!(id)
    changeset = Input.change_redis_instance(redis_instance)
    render(conn, :edit, redis_instance: redis_instance, changeset: changeset)
  end

  def update(conn, %{"id" => id, "redis_instance" => redis_instance_params}) do
    redis_instance = Input.get_redis_instance!(id)

    case Input.update_redis_instance(redis_instance, redis_instance_params) do
      {:ok, redis_instance} ->
        conn
        |> put_flash(:info, "Redis instance updated successfully.")
        |> redirect(to: ~p"/admin/redisinstances/#{redis_instance}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, redis_instance: redis_instance, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    redis_instance = Input.get_redis_instance!(id)
    {:ok, _redis_instance} = Input.delete_redis_instance(redis_instance)
    Input.RedisInstance.terminate(redis_instance)

    conn
    |> put_flash(:info, "Redis instance deleted successfully.")
    |> redirect(to: ~p"/admin/redisinstances")
  end
end
