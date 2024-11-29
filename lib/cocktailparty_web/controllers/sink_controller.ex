defmodule CocktailpartyWeb.SinkController do
  use CocktailpartyWeb, :controller

  alias Cocktailparty.SinkCatalog
  import CocktailpartyWeb.AccessControl

  plug :sink_access_control when action in [:index, :show]
  # :show and :edit access control is the controller to avoid duplicating DB request

  def index(conn, _params) do
    sinks = SinkCatalog.list_user_sinks(conn.assigns.current_user.id)
    render(conn, :index, sinks: sinks)
  end

  def show(conn, %{"id" => id}) do
    sink = SinkCatalog.get_auth_sink(id, conn.assigns.current_user.id)

    case sink do
      {:ok, sink} ->
        sample = SinkCatalog.get_sample(id)
        render(conn, :show, sink: sink, sample: sample)

      {:error, "Unauthorized"} ->
        conn
        |> put_flash(:error, "Unauthorized")
        |> redirect(to: ~p"/sinks")
    end
  end
end
