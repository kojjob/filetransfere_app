defmodule FiletransferWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :filetransfer_web

  @session_options [
    store: :cookie,
    key: "_filetransfer_web_key",
    signing_salt: "dfMZRG8G",
    same_site: "Lax"
  ]

  # User socket for real-time transfer progress
  socket "/socket", FiletransferWeb.UserSocket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :filetransfer_web,
    gzip: not code_reloading?,
    only: FiletransferWeb.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug FiletransferWeb.Router
end
