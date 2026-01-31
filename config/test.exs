import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ddbm, Ddbm.Repo,
  database: Path.expand("../ddbm_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ddbm_web, DdbmWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "kre06njItIKhxXF4t88uAxnRby8VEl7gWYQaDAHbE4STDuOZNceXYcsY7d51pGH3",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable Oban during tests
config :ddbm, Oban,
  testing: :manual,
  queues: false,
  plugins: false

# Disable Discord bot in test
config :ddbm_discord, start_bot: false
