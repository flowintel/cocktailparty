defmodule Cocktailparty.Input do
  @moduledoc """
  The Input context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Cocktailparty.Repo

  alias Cocktailparty.Input.RedisInstance

  @doc """
  Returns the list of redisinstances.

  ## Examples

      iex> list_redisinstances()
      [%RedisInstance{}, ...]

  """
  def list_redisinstances do
    Repo.all(RedisInstance)
    |> Enum.map(fn instance ->
      instance
      |> Map.put(:connected, connected?(instance))
    end)
  end

  @doc """
  Returns the list of redis intances that can be used to push data in

  ## Examples

      iex> list_redisinstances()
      [%RedisInstance{}, ...]

  """
  def list_sink_redisinstances do
    Repo.all(from r in RedisInstance, where: r.sink == true)
  end

  @doc """
  Returns the list of redis intances that can be used to push data in

  ## Examples

      iex> list_redisinstances()
      [%RedisInstance{}, ...]

  """
  def get_one_sink_redisinstance do
    Repo.one(from r in RedisInstance, where: r.sink == true)
  end

  @doc """
  Returns the list of redisinstances for feeding a select component

  ## Examples

      iex> list_redisinstances()
      [{"name", 1}]

  """
  def list_redisinstances_for_select do
    Repo.all(from r in "redis_instances", select: {r.name, r.id})
  end

  @doc """
  Gets a single redis_instance.

  Raises `Ecto.NoResultsError` if the Redis instance does not exist.

  ## Examples

      iex> get_redis_instance!(123)
      %RedisInstance{}

      iex> get_redis_instance!(456)
      ** (Ecto.NoResultsError)

  """
  def get_redis_instance!(id) do
    instance = Repo.get!(RedisInstance, id)
    Map.put(instance, :connected, connected?(instance))
  end


  @doc """
  Creates a redis_instance.

  ## Examples

      iex> create_redis_instance(%{field: value})
      {:ok, %RedisInstance{}}

      iex> create_redis_instance(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_redis_instance(attrs \\ %{}) do
    %RedisInstance{}
    |> RedisInstance.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a redis_instance.

  ## Examples

      iex> update_redis_instance(redis_instance, %{field: new_value})
      {:ok, %RedisInstance{}}

      iex> update_redis_instance(redis_instance, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_redis_instance(%RedisInstance{} = redis_instance, attrs) do
    changeset = change_redis_instance(redis_instance, attrs)

    # We restart related processes if needed
    # TODO: check enabled
    if changed?(changeset, :hostname) or changed?(changeset, :port) do
      RedisInstance.terminate(redis_instance)
      {:ok, redis_instance} = Repo.update(changeset)
      RedisInstance.start(redis_instance)
      {:ok, redis_instance}
    else
      Repo.update(changeset)
    end
  end

  @doc """
  Deletes a redis_instance.

  ## Examples

      iex> delete_redis_instance(redis_instance)
      {:ok, %RedisInstance{}}

      iex> delete_redis_instance(redis_instance)
      {:error, %Ecto.Changeset{}}

  """
  def delete_redis_instance(%RedisInstance{} = redis_instance) do
    Repo.delete(redis_instance)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking redis_instance changes.

  ## Examples

      iex> change_redis_instance(redis_instance)
      %Ecto.Changeset{data: %RedisInstance{}}

  """
  def change_redis_instance(%RedisInstance{} = redis_instance, attrs \\ %{}) do
    RedisInstance.changeset(redis_instance, attrs)
  end

  @doc """
  Get the status of a redis connection

  """
  def connected?(%RedisInstance{} = redis_instance) do
    case GenServer.whereis({:global, "redix_" <> Integer.to_string(redis_instance.id)}) do
      nil ->
        false

      # name, node
      {_, _} ->
        true

      # pid
      pid ->
        case :sys.get_state(pid) do
          {:connected, _} ->
            true

          _ ->
            false
        end
    end
  end
end
