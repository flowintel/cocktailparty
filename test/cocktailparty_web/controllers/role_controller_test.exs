defmodule CocktailpartyWeb.RoleControllerTest do
  use CocktailpartyWeb.ConnCase

  import Cocktailparty.RolesFixtures

  @create_attrs %{name: "some name", permissions: %{}}
  @update_attrs %{name: "some updated name", permissions: %{}}
  @invalid_attrs %{name: nil, permissions: nil}

  describe "index" do
    test "lists all roles", %{conn: conn} do
      conn = get(conn, ~p"/roles")
      assert html_response(conn, 200) =~ "Listing Roles"
    end
  end

  describe "new role" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/roles/new")
      assert html_response(conn, 200) =~ "New Role"
    end
  end

  describe "create role" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/roles", role: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/roles/#{id}"

      conn = get(conn, ~p"/roles/#{id}")
      assert html_response(conn, 200) =~ "Role #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/roles", role: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Role"
    end
  end

  describe "edit role" do
    setup [:create_role]

    test "renders form for editing chosen role", %{conn: conn, role: role} do
      conn = get(conn, ~p"/roles/#{role}/edit")
      assert html_response(conn, 200) =~ "Edit Role"
    end
  end

  describe "update role" do
    setup [:create_role]

    test "redirects when data is valid", %{conn: conn, role: role} do
      conn = put(conn, ~p"/roles/#{role}", role: @update_attrs)
      assert redirected_to(conn) == ~p"/roles/#{role}"

      conn = get(conn, ~p"/roles/#{role}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, role: role} do
      conn = put(conn, ~p"/roles/#{role}", role: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Role"
    end
  end

  describe "delete role" do
    setup [:create_role]

    test "deletes chosen role", %{conn: conn, role: role} do
      conn = delete(conn, ~p"/roles/#{role}")
      assert redirected_to(conn) == ~p"/roles"

      assert_error_sent 404, fn ->
        get(conn, ~p"/roles/#{role}")
      end
    end
  end

  defp create_role(_) do
    role = role_fixture()
    %{role: role}
  end
end
