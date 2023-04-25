defmodule Cocktailparty.CatalogTest do
  use Cocktailparty.DataCase

  alias Cocktailparty.Catalog

  describe "sources" do
    alias Cocktailparty.Catalog.Source

    import Cocktailparty.CatalogFixtures

    @invalid_attrs %{channel: nil, description: nil, driver: nil, name: nil, type: nil, url: nil}

    test "list_sources/0 returns all sources" do
      source = source_fixture()
      assert Catalog.list_sources() == [source]
    end

    test "get_source!/1 returns the source with given id" do
      source = source_fixture()
      assert Catalog.get_source!(source.id) == source
    end

    test "create_source/1 with valid data creates a source" do
      valid_attrs = %{
        channel: "some channel",
        description: "some description",
        driver: "some driver",
        name: "some name",
        type: "some type",
        url: "some url"
      }

      assert {:ok, %Source{} = source} = Catalog.create_source(valid_attrs)
      assert source.channel == "some channel"
      assert source.description == "some description"
      assert source.driver == "some driver"
      assert source.name == "some name"
      assert source.type == "some type"
      assert source.url == "some url"
    end

    test "create_source/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_source(@invalid_attrs)
    end

    test "update_source/2 with valid data updates the source" do
      source = source_fixture()

      update_attrs = %{
        channel: "some updated channel",
        description: "some updated description",
        driver: "some updated driver",
        name: "some updated name",
        type: "some updated type",
        url: "some updated url"
      }

      assert {:ok, %Source{} = source} = Catalog.update_source(source, update_attrs)
      assert source.channel == "some updated channel"
      assert source.description == "some updated description"
      assert source.driver == "some updated driver"
      assert source.name == "some updated name"
      assert source.type == "some updated type"
      assert source.url == "some updated url"
    end

    test "update_source/2 with invalid data returns error changeset" do
      source = source_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_source(source, @invalid_attrs)
      assert source == Catalog.get_source!(source.id)
    end

    test "delete_source/1 deletes the source" do
      source = source_fixture()
      assert {:ok, %Source{}} = Catalog.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_source!(source.id) end
    end

    test "change_source/1 returns a source changeset" do
      source = source_fixture()
      assert %Ecto.Changeset{} = Catalog.change_source(source)
    end
  end
end
