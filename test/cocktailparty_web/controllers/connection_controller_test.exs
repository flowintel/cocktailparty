defmodule CocktailpartyWeb.ConnectionControllerTest do
  use CocktailpartyWeb.ConnCase
  # use CocktailpartyWeb.DataCase

  import Cocktailparty.InputFixtures

  @create_attrs %{
    enabled: true,
    sink: false,
    name: "some name",
    type: "redis",
    config: "---\nhostname: redis.example.com\nport: 6380\n"
  }
  @update_attrs %{
    enabled: false,
    name: "some updated name",
    type: "redis",
    config: "---\nhostname: redis.example.com\nport: 6379\n"
  }
  @invalid_attrs_missing %{
    enabled: nil,
    name: nil,
    type: "redis",
    config: "---\nhostname: redis.example.com\nport: 6379\n"
  }
  @invalid_attrs_broken_yaml %{
    enabled: nil,
    name: nil,
    type: "redis",
    config: "---\nhostname: redis.example.com\nport:|\n\n\r4242\n: 6379"
  }
  @invalid_attrs_missing_yaml %{
    enabled: nil,
    name: nil,
    type: "redis",
    config: "---\nhostname: redis.example.com\n"
  }

  describe "index" do
    setup [:register_and_log_in_admin]

    test "lists all connections", %{conn: conn} do
      conn = get(conn, ~p"/admin/connections")
      dbg(conn)

      assert html_response(conn, 200) =~ "Listing connections"
    end
  end

  describe "new connection" do
    setup [:register_and_log_in_admin]

    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/admin/connections/new")
      assert html_response(conn, 200) =~ "New connection"
    end
  end

  describe "create connection" do
    setup [:register_and_log_in_admin]

    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/admin/connections", connection: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/admin/connections/#{id}"

      conn = get(conn, ~p"/admin/connections/#{id}")
      assert html_response(conn, 200) =~ "Connection #{id}"
    end

    test "renders errors when data is missing", %{conn: conn} do
      conn = post(conn, ~p"/admin/connections", connection: @invalid_attrs_missing)

      assert html_response(conn, 200) =~ "be blank"
    end

    test "renders errors when YAML data is missing", %{conn: conn} do
      conn = post(conn, ~p"/admin/connections", connection: @invalid_attrs_missing_yaml)
      assert html_response(conn, 200) =~ "Missing required keys in config"
    end

    # TODO this should not raise anynore when fixed
    test "renders errors when YAML data is broken", %{conn: conn} do
      conn = post(conn, ~p"/admin/connections", connection: @invalid_attrs_broken_yaml)
      assert html_response(conn, 200) =~ "Failed to parse"
    end
  end

  describe "edit connection" do
    setup [:register_and_log_in_admin]
    setup [:create_connection]

    test "renders form for editing chosen connection", %{
      conn: conn,
      connection: connection
    } do
      conn = get(conn, ~p"/admin/connections/#{connection.id}/edit")
      assert html_response(conn, 200) =~ "Edit Connection #{connection.id}"
    end
  end

  describe "update connection" do
    setup [:register_and_log_in_admin]
    setup [:create_connection]

    test "redirects when data is valid", %{conn: conn, connection: connection} do
      conn = put(conn, ~p"/admin/connections/#{connection.id}", connection: @update_attrs)
      assert redirected_to(conn) == ~p"/admin/connections/#{connection.id}"

      conn = get(conn, ~p"/admin/connections/#{connection.id}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, connection: connection} do
      conn =
        put(conn, ~p"/admin/connections/#{connection.id}",
          connection: @invalid_attrs_missing_yaml
        )

      assert html_response(conn, 200) =~ "Missing required keys in config"
    end
  end

  describe "delete connection" do
    setup [:register_and_log_in_admin]
    setup [:create_connection]

    test "deletes chosen connection", %{conn: conn, connection: connection} do
      conn = delete(conn, ~p"/admin/connections/#{connection}")
      assert redirected_to(conn) == ~p"/admin/connections"

      assert_error_sent 404, fn ->
        get(conn, ~p"/admin/connections/#{connection}")
      end
    end
  end

  defp create_connection(_) do
    connection = connection_fixture()
    %{connection: connection}
  end
end
