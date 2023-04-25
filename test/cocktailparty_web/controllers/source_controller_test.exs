defmodule CocktailpartyWeb.SourceControllerTest do
  use CocktailpartyWeb.ConnCase

  import Cocktailparty.CatalogFixtures

  @create_attrs %{
    channel: "some channel",
    description: "some description",
    driver: "some driver",
    name: "some name",
    type: "some type",
    url: "some url"
  }
  @update_attrs %{
    channel: "some updated channel",
    description: "some updated description",
    driver: "some updated driver",
    name: "some updated name",
    type: "some updated type",
    url: "some updated url"
  }
  @invalid_attrs %{channel: nil, description: nil, driver: nil, name: nil, type: nil, url: nil}

  describe "index" do
    test "lists all sources", %{conn: conn} do
      conn = get(conn, ~p"/sources")
      assert html_response(conn, 200) =~ "Listing Sources"
    end
  end

  describe "new source" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/sources/new")
      assert html_response(conn, 200) =~ "New Source"
    end
  end

  describe "create source" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/sources", source: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/sources/#{id}"

      conn = get(conn, ~p"/sources/#{id}")
      assert html_response(conn, 200) =~ "Source #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/sources", source: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Source"
    end
  end

  describe "edit source" do
    setup [:create_source]

    test "renders form for editing chosen source", %{conn: conn, source: source} do
      conn = get(conn, ~p"/sources/#{source}/edit")
      assert html_response(conn, 200) =~ "Edit Source"
    end
  end

  describe "update source" do
    setup [:create_source]

    test "redirects when data is valid", %{conn: conn, source: source} do
      conn = put(conn, ~p"/sources/#{source}", source: @update_attrs)
      assert redirected_to(conn) == ~p"/sources/#{source}"

      conn = get(conn, ~p"/sources/#{source}")
      assert html_response(conn, 200) =~ "some updated channel"
    end

    test "renders errors when data is invalid", %{conn: conn, source: source} do
      conn = put(conn, ~p"/sources/#{source}", source: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Source"
    end
  end

  describe "delete source" do
    setup [:create_source]

    test "deletes chosen source", %{conn: conn, source: source} do
      conn = delete(conn, ~p"/sources/#{source}")
      assert redirected_to(conn) == ~p"/sources"

      assert_error_sent 404, fn ->
        get(conn, ~p"/sources/#{source}")
      end
    end
  end

  defp create_source(_) do
    source = source_fixture()
    %{source: source}
  end
end
