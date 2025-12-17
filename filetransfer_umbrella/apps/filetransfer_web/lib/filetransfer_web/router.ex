defmodule FiletransferWeb.Router do
  use FiletransferWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FiletransferWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug FiletransferWeb.Plugs.CORS
  end

  pipeline :authenticated do
    plug FiletransferWeb.Plugs.RequireAuth
  end

  scope "/", FiletransferWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api/auth", FiletransferWeb do
    pipe_through :api

    post "/register", AuthController, :register
    post "/login", AuthController, :login
    post "/logout", AuthController, :logout
    get "/me", AuthController, :current_user
  end

  # Public API routes (no authentication required)
  scope "/api", FiletransferWeb do
    pipe_through :api

    options "/waitlist", WaitlistController, :options
    post "/waitlist", WaitlistController, :create
  end

  # Protected API routes
  scope "/api", FiletransferWeb do
    pipe_through [:api, :authenticated]

    # Transfer routes will go here
  end

  # Admin routes (secure these in production!)
  scope "/admin", FiletransferWeb do
    pipe_through :browser

    live "/waitlist", Admin.WaitlistLive, :index
  end

  # Admin API routes (for exports)
  scope "/admin", FiletransferWeb.Admin do
    pipe_through :api

    get "/waitlist/export", WaitlistController, :export
    get "/waitlist/stats", WaitlistController, :stats
  end
end
