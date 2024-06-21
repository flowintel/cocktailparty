defmodule CocktailpartyWeb.ConnectionControllerTest do
  use CocktailpartyWeb.ConnCase

  import Cocktailparty.InputFixtures

  @create_attrs %{enabled: true, name: "some name", uri: "some uri"}
  @update_attrs %{enabled: false, name: "some updated name", uri: "some updated uri"}
  @invalid_attrs %{enabled: nil, name: nil, uri: nil}

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
      assert html_response(conn, 200) =~ "connection #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/admin/connections", connection: @invalid_attrs)
      assert html_response(conn, 200) =~ "New connection"
    end
  end

  describe "edit connection" do
    setup [:register_and_log_in_admin]
    setup [:create_connection]

    test "renders form for editing chosen connection", %{
      conn: conn,
      connection: connection
    } do
      conn = get(conn, ~p"/admin/connections/#{connection}/edit")
      assert html_response(conn, 200) =~ "Edit connection"
    end
  end

  @tag run: true
  describe "update connection" do
    setup [:register_and_log_in_admin]
    setup [:create_connection]

    test "redirects when data is valid", %{conn: conn, connection: connection} do
      conn = put(conn, ~p"/admin/connections/#{connection}", connection: @update_attrs)
      assert redirected_to(conn) == ~p"/admin/connections/#{connection}"

      conn = get(conn, ~p"/admin/connections/#{connection}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, connection: connection} do
      conn = put(conn, ~p"/admin/connections/#{connection}", connection: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit connection"
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
