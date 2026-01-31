defmodule DdbmWeb.Router do
  use DdbmWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DdbmWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug DdbmWeb.Plugs.LoadCurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_auth do
    plug DdbmWeb.Plugs.RequireAuth
  end

  scope "/", DdbmWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Authentication routes
  scope "/auth", DdbmWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    post "/:provider/callback", AuthController, :callback
  end

  scope "/", DdbmWeb do
    pipe_through :browser

    delete "/logout", AuthController, :delete
  end

  # Authenticated routes
  scope "/", DdbmWeb do
    pipe_through [:browser, :require_auth]

    live_session :authenticated,
      on_mount: [{DdbmWeb.UserAuth, :require_authenticated_user}] do
      live "/dashboard", DashboardLive, :index
      live "/tokens/leaderboard", LeaderboardLive, :index
      live "/tokens/log", LogLive, :index
      live "/tokens/give", GiveLive, :index
      live "/admin", AdminLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", DdbmWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:ddbm_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DdbmWeb.Telemetry
    end
  end
end
