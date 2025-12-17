import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# Start Phoenix server if PHX_SERVER is set
if System.get_env("PHX_SERVER") do
  config :filetransfer_web, FiletransferWeb.Endpoint, server: true
end

# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :filetransfer_web, FiletransferWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :filetransfer_web, FiletransferWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :filetransfer_web, FiletransferWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :filetransfer_web, FiletransferWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  config :filetransfer_core, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Configure Swoosh mailer with Resend for production
  if resend_api_key = System.get_env("RESEND_API_KEY") do
    config :filetransfer_web, FiletransferWeb.Mailer,
      adapter: Swoosh.Adapters.Resend,
      api_key: resend_api_key
  end

  # Database configuration
  # For Fly.io with IPv6, we need to configure explicitly instead of using URL
  # since URL parsing doesn't handle IPv6 brackets properly
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  # Parse database URL to extract components
  uri = URI.parse(database_url)
  userinfo = uri.userinfo || ""

  [username, password] =
    case String.split(userinfo, ":") do
      [user, pass] -> [user, pass]
      [user] -> [user, nil]
      _ -> [nil, nil]
    end

  # Handle IPv6 hosts (they come with brackets in URL)
  host =
    case uri.host do
      nil -> "localhost"
      h when is_binary(h) -> h
    end

  # Extract database name from path
  database =
    case uri.path do
      "/" <> db -> db
      db when is_binary(db) -> db
      _ -> "zipshare_api"
    end

  pool_size = String.to_integer(System.get_env("POOL_SIZE") || "10")

  # Check if host is an IPv6 address (contains colons)
  socket_options = if String.contains?(host, ":"), do: [:inet6], else: []

  config :filetransfer_core, FiletransferCore.Repo,
    username: username,
    password: password,
    hostname: host,
    database: database,
    port: uri.port || 5432,
    pool_size: pool_size,
    socket_options: socket_options
end
