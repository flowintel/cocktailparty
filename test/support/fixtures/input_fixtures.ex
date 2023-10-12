defmodule Cocktailparty.InputFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Cocktailparty.Input` context.
  """

  @doc """
  Generate a unique redis_instance name.
  """
  def unique_redis_instance_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique redis_instance uri.
  """
  def unique_redis_instance_uri, do: "some uri#{System.unique_integer([:positive])}"

  @doc """
  Generate a redis_instance.
  """
  def redis_instance_fixture(attrs \\ %{}) do
    {:ok, redis_instance} =
      attrs
      |> Enum.into(%{
        enabled: true,
        name: unique_redis_instance_name(),
        uri: unique_redis_instance_uri()
      })
      |> Cocktailparty.Input.create_redis_instance()

    redis_instance
  end
end
