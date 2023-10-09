defmodule CocktailpartyWeb.SinkControllerTest do
  use CocktailpartyWeb.ConnCase

  import Cocktailparty.SinkCatalogFixtures

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  describe "index" do
    test "lists all sinks", %{conn: conn} do
      conn = get(conn, ~p"/sinks")
      assert html_response(conn, 200) =~ "Listing Sinks"
    end
  end

  describe "new sink" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/sinks/new")
      assert html_response(conn, 200) =~ "New Sink"
    end
  end

  describe "create sink" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/sinks", sink: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/sinks/#{id}"

      conn = get(conn, ~p"/sinks/#{id}")
      assert html_response(conn, 200) =~ "Sink #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/sinks", sink: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Sink"
    end
  end

  describe "edit sink" do
    setup [:create_sink]

    test "renders form for editing chosen sink", %{conn: conn, sink: sink} do
      conn = get(conn, ~p"/sinks/#{sink}/edit")
      assert html_response(conn, 200) =~ "Edit Sink"
    end
  end

  describe "update sink" do
    setup [:create_sink]

    test "redirects when data is valid", %{conn: conn, sink: sink} do
      conn = put(conn, ~p"/sinks/#{sink}", sink: @update_attrs)
      assert redirected_to(conn) == ~p"/sinks/#{sink}"

      conn = get(conn, ~p"/sinks/#{sink}")
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, sink: sink} do
      conn = put(conn, ~p"/sinks/#{sink}", sink: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Sink"
    end
  end

  describe "delete sink" do
    setup [:create_sink]

    test "deletes chosen sink", %{conn: conn, sink: sink} do
      conn = delete(conn, ~p"/sinks/#{sink}")
      assert redirected_to(conn) == ~p"/sinks"

      assert_error_sent 404, fn ->
        get(conn, ~p"/sinks/#{sink}")
      end
    end
  end

  defp create_sink(_) do
    sink = sink_fixture()
    %{sink: sink}
  end
end
