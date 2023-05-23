defmodule CocktailpartyWeb.Router do
  use CocktailpartyWeb, :router

  import CocktailpartyWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {CocktailpartyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :default_admin_rights
  end

  pipeline :mounted_apps do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :default_admin_rights
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug :fetch_current_user
    plug :require_authenticated_user
    plug :put_user_token
    plug :set_admin_rights
  end

  pipeline :require_admin do
    plug :require_admin_user
  end

  scope "/", CocktailpartyWeb do
    pipe_through [:browser, :auth]
    get "/", PageController, :home
    get "/sources", SourceController, :index
    get "/sources/:id", SourceController, :show
    post "/sources/:id", SourceController, :subscribe
    delete "/sources/:id", SourceController, :unsubscribe
  end

  scope "/admin", CocktailpartyWeb.Admin do
    pipe_through [:browser, :auth, :require_admin]
    resources "/users", UserController
    resources "/sources", SourceController
  end

  scope path: "/feature-flags" do
    pipe_through [:mounted_apps, :auth, :require_admin]
    forward "/", FunWithFlags.UI.Router, namespace: "feature-flags"
  end

  # Other scopes may use custom stacks.
  # scope "/api", CocktailpartyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:cocktailparty, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CocktailpartyWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", CocktailpartyWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{CocktailpartyWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", CocktailpartyWeb do
    pipe_through [:browser, :auth]

    live_session :require_authenticated_user,
      on_mount: [{CocktailpartyWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", CocktailpartyWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{CocktailpartyWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # plug function to assigns the user token needed to connect to the socket
  defp put_user_token(conn, _) do
    if current_user = conn.assigns[:current_user] do
      token = Phoenix.Token.sign(conn, "user socket", current_user.id)
      assign(conn, :user_token, token)
    else
      conn
    end
  end
end
