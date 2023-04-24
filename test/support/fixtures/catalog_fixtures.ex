defmodule Cocktailparty.CatalogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Cocktailparty.Catalog` context.
  """

  @doc """
  Generate a source.
  """
  def source_fixture(attrs \\ %{}) do
    {:ok, source} =
      attrs
      |> Enum.into(%{
        channel: "some channel",
        description: "some description",
        driver: "some driver",
        name: "some name",
        type: "some type",
        url: "some url"
      })
      |> Cocktailparty.Catalog.create_source()

    source
  end
end
