import Config

# Mark this as test environment for admin auth
config :filetransfer_web, env: :test

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :filetransfer_web, FiletransferWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "3qhkPo6Cr5HbgkDAcYP6XLdkeVsQzCcGmKjeOve+Y08OWZSuLTC5GcNd5g7r7ZRe",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Configure the database for tests
config :filetransfer_core, FiletransferCore.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "filetransfer_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
