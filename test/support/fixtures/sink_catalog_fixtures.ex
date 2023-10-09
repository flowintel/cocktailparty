defmodule Cocktailparty.SinkCatalogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Cocktailparty.SinkCatalog` context.
  """

  @doc """
  Generate a sink.
  """

  import Cocktailparty.UserManagementFixtures

  def sink_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()

    name = for _ <- 1..10, into: "", do: <<Enum.random(~c"0123456789abcdef")>>

    attrs
    |> Enum.into(%{
      channel: "Some test channel",
      description: "Some test description",
      name: name,
      type: "Some test type"
    })

    {:ok, sink} =
      Ecto.build_assoc(user, :sinks, attrs)
      |> Cocktailparty.Repo.insert()

    sink
  end
end
