defmodule Cocktailparty.Input do
  @moduledoc """
  The Input context.
  """

  import Ecto.Query, warn: false
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
  def get_redis_instance!(id), do: Repo.get!(RedisInstance, id)

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
    redis_instance
    |> RedisInstance.changeset(attrs)
    |> Repo.update()
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
end
