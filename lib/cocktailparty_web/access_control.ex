defmodule CocktailpartyWeb.AccessControl do
  use CocktailpartyWeb, :verified_routes
  import Phoenix.Controller
  import Plug.Conn

  alias Cocktailparty.UserManagement
  alias Cocktailparty.Catalog

  @doc """
  Access to :show route to a source is restricted by:
   - whether a user is confirmed or not
   - the user role and its permissions
   - whether or not a user is subscribed to a source
   - if the source is public
  """
  def show_source_access_control(conn, _opts) do
    if show_source_authorized?(conn) do
      conn
    else
      conn
      |> put_flash(:error, "Not authorized")
      |> redirect(to: "/sources")
      |> halt()
    end
  end

  defp show_source_authorized?(conn) do
    user_id = conn.assigns.current_user.id
    source_id = conn.params["id"]

    (UserManagement.is_confirmed?(user_id) && Catalog.is_subscribed?(source_id, user_id)) ||
      (UserManagement.is_confirmed?(user_id) &&
         (UserManagement.can?(user_id, :access_all_sources) ||
            UserManagement.can?(user_id, :list_all_sources))) ||
      (UserManagement.is_confirmed?(user_id) && Catalog.is_public?(source_id))
  end

  @doc """
  Access to :index route to a source is restricted by:
   - whether a user is confirmed or not
  Further filtering is done on the data layer
  """
  def index_source_access_control(conn, _opts) do
    if index_source_authorized?(conn) do
      conn
    else
      conn
      |> put_flash(:error, "Your account needs to be confirmed by an admin.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  defp index_source_authorized?(conn) do
    UserManagement.is_confirmed?(conn.assigns.current_user.id)
  end

  @doc """
  Access to :index, :show route to a sink are restricted by:
   - whether the user is confirmed or not
   - whether they have :create_sinks or :use_sinks permission
  """
  def see_sinks_access_control(conn, _opts) do
    if (UserManagement.is_confirmed?(conn.assigns.current_user.id) &&
          UserManagement.can?(conn.assigns.current_user.id, :create_sinks)) or
         UserManagement.can?(conn.assigns.current_user.id, :use_sinks) do
      conn
    else
      conn
      |> put_flash(:error, "Unauthorized")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  @doc """
  Access to :create, :update, :edit route
  """
  def create_sinks_access_control(conn, _opts) do
    if can_create_sink?(conn.assigns.current_user.id) do
      conn
    else
      conn
      |> put_flash(:error, "Unauthorized")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  @doc """
  Return whether or not a user can create sinks. Depends:
   - whether the user is confirmed or not
   - whether they have :create_sinks or :use_sinks permission
  """
  def can_create_sink?(user_id) do
    UserManagement.is_confirmed?(user_id) &&
      UserManagement.can?(user_id, :create_sinks)
  end
end
