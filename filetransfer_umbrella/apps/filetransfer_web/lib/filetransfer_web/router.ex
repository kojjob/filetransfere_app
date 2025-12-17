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

  pipeline :admin_auth do
    plug FiletransferWeb.Plugs.RequireAdmin
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

  # Public API routes
  scope "/api", FiletransferWeb do
    pipe_through :api
    options "/waitlist", WaitlistController, :options
    post "/waitlist", WaitlistController, :create
  end

  # Protected API routes
  scope "/api", FiletransferWeb do
    pipe_through [:api, :authenticated]

    # Transfer management
    get "/transfers", TransferController, :index
    post "/transfers", TransferController, :create
    get "/transfers/:id", TransferController, :show
    delete "/transfers/:id", TransferController, :delete
    get "/transfers/:id/resume", TransferController, :resume
    post "/transfers/:id/chunks/:index", TransferController, :update_chunk

    # Upload operations
    post "/transfers/:id/upload/init", UploadController, :init_multipart
    post "/transfers/:id/upload/chunk", UploadController, :upload_chunk
    post "/transfers/:id/upload/complete", UploadController, :complete_upload
    post "/transfers/:id/upload/abort", UploadController, :abort_upload
    get "/transfers/:id/upload/presigned", UploadController, :presigned_url

    # Download operations
    get "/transfers/:id/download", DownloadController, :download
    get "/transfers/:id/download/url", DownloadController, :presigned_url

    # Share link management
    post "/transfers/:id/share", ShareController, :create
    get "/shares", ShareController, :index
    get "/shares/:id", ShareController, :show
    patch "/shares/:id", ShareController, :update
    delete "/shares/:id", ShareController, :delete
  end

  # Public share access
  scope "/s", FiletransferWeb do
    pipe_through :api
    get "/:token", ShareController, :access
    post "/:token/download", ShareController, :download
  end

  # Admin routes
  scope "/admin", FiletransferWeb do
    pipe_through [:browser, :admin_auth]
    live "/waitlist", Admin.WaitlistLive, :index
  end

  scope "/admin", FiletransferWeb.Admin do
    pipe_through [:api, :admin_auth]
    get "/waitlist/export", WaitlistController, :export
    get "/waitlist/stats", WaitlistController, :stats
  end
end
