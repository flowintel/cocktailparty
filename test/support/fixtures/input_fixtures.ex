defmodule Cocktailparty.InputFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Cocktailparty.Input` context.
  """

  @doc """
  Generate a unique connection name.
  """
  def unique_connection_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique connection uri.
  """
  def unique_connection_uri, do: "some uri#{System.unique_integer([:positive])}"

  @doc """
  Generate a connection.
  """
  def connection_fixture(attrs \\ %{}) do
    {:ok, connection} =
      attrs
      |> Enum.into(%{
        enabled: true,
        name: unique_connection_name(),
        type: "redis",
        config: %{hostname: "localhost", port: 6379}
      })
      |> Cocktailparty.Input.create_connection()

    connection
  end
end
