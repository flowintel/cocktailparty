defmodule CocktailpartyWeb.RedisInstanceControllerTest do
  use CocktailpartyWeb.ConnCase

  import Cocktailparty.InputFixtures

  @create_attrs %{enabled: true, name: "some name", uri: "some uri"}
  @update_attrs %{enabled: false, name: "some updated name", uri: "some updated uri"}
  @invalid_attrs %{enabled: nil, name: nil, uri: nil}

  describe "index" do
    test "lists all redisinstances", %{conn: conn} do
      conn = get(conn, ~p"/redisinstances")
      assert html_response(conn, 200) =~ "Listing Redisinstances"
    end
  end

  describe "new redis_instance" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/redisinstances/new")
      assert html_response(conn, 200) =~ "New Redis instance"
    end
  end

  describe "create redis_instance" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/redisinstances", redis_instance: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/redisinstances/#{id}"

      conn = get(conn, ~p"/redisinstances/#{id}")
      assert html_response(conn, 200) =~ "Redis instance #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/redisinstances", redis_instance: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Redis instance"
    end
  end

  describe "edit redis_instance" do
    setup [:create_redis_instance]

    test "renders form for editing chosen redis_instance", %{
      conn: conn,
      redis_instance: redis_instance
    } do
      conn = get(conn, ~p"/redisinstances/#{redis_instance}/edit")
      assert html_response(conn, 200) =~ "Edit Redis instance"
    end
  end

  describe "update redis_instance" do
    setup [:create_redis_instance]

    test "redirects when data is valid", %{conn: conn, redis_instance: redis_instance} do
      conn = put(conn, ~p"/redisinstances/#{redis_instance}", redis_instance: @update_attrs)
      assert redirected_to(conn) == ~p"/redisinstances/#{redis_instance}"

      conn = get(conn, ~p"/redisinstances/#{redis_instance}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, redis_instance: redis_instance} do
      conn = put(conn, ~p"/redisinstances/#{redis_instance}", redis_instance: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Redis instance"
    end
  end

  describe "delete redis_instance" do
    setup [:create_redis_instance]

    test "deletes chosen redis_instance", %{conn: conn, redis_instance: redis_instance} do
      conn = delete(conn, ~p"/redisinstances/#{redis_instance}")
      assert redirected_to(conn) == ~p"/redisinstances"

      assert_error_sent 404, fn ->
        get(conn, ~p"/redisinstances/#{redis_instance}")
      end
    end
  end

  defp create_redis_instance(_) do
    redis_instance = redis_instance_fixture()
    %{redis_instance: redis_instance}
  end
end
