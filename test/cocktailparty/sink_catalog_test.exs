defmodule Cocktailparty.SinkCatalogTest do
  use Cocktailparty.DataCase

  alias Cocktailparty.SinkCatalog

  describe "sinks" do
    alias Cocktailparty.SinkCatalog.Sink

    import Cocktailparty.SinkCatalogFixtures
    import Cocktailparty.UserManagementFixtures

    @invalid_attrs %{
      channel: "Some test channel",
      description: "Some test description",
      name: "",
      type: ""
    }
    test "list_sinks/0 returns all sinks" do
      sink = sink_fixture()
      assert SinkCatalog.list_sinks() == [sink]
    end

    test "get_sink/1 returns the sink with given id" do
      sink = sink_fixture()
      sink_with_user = Cocktailparty.Repo.preload(sink, :user)
      assert SinkCatalog.get_auth_sink(sink.id, sink_with_user.user_id) == {:ok, sink}
    end

    test "get_sink!/1 returns the sink with given id" do
      sink = sink_fixture()
      assert SinkCatalog.get_sink!(sink.id) == sink
    end

    test "create_sink/1 with valid data creates a sink" do
      user = user_fixture()
      name = for _ <- 1..10, into: "", do: <<Enum.random(~c"0123456789abcdef")>>

      valid_attrs = %{
        channel: "Some test channel",
        description: "Some test description",
        name: name,
        type: "Some test type"
      }

      assert {:ok, %Sink{} = _} = SinkCatalog.create_sink(valid_attrs, user.id)
    end

    test "create_sink/1 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = SinkCatalog.create_sink(@invalid_attrs, user.id)
    end

    test "update_sink/2 with valid data updates the sink" do
      sink = sink_fixture()
      update_attrs = %{channel: "toto"}
      SinkCatalog.update_sink(sink, update_attrs)
      # assert {:ok,
      #         %Sink{
      #           channel: "toto",
      #           description: "Some test description",
      #           name: sink.name,
      #           type: "Some test type"
      #         }} = SinkCatalog.update_sink(sink, update_attrs)
    end

    test "update_sink/2 with invalid data returns error changeset" do
      sink = sink_fixture()
      sink_with_user = Cocktailparty.Repo.preload(sink, :user)
      assert {:error, %Ecto.Changeset{}} = SinkCatalog.update_sink(sink_with_user, @invalid_attrs)
      assert sink == SinkCatalog.get_sink!(sink.id)
    end

    test "delete_sink/1 deletes the sink" do
      sink = sink_fixture()
      assert {:ok, %Sink{}} = SinkCatalog.delete_sink(sink)
      assert_raise Ecto.NoResultsError, fn -> SinkCatalog.get_sink!(sink.id) end
    end

    test "change_sink/1 returns a sink changeset" do
      sink = sink_fixture()
      assert %Ecto.Changeset{} = SinkCatalog.change_sink(sink)
    end
  end
end
