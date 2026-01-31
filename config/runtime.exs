import Config

# Load .env file in dev/test (not in releases)
env =
  if config_env() in [:dev, :test] and File.exists?(".env") do
    Dotenvy.source!([".env"])
  else
    %{}
  end

# Discord OAuth configuration
if client_id = env["DISCORD_OAUTH_CLIENT_ID"] || System.get_env("DISCORD_OAUTH_CLIENT_ID") do
  if client_secret = env["DISCORD_OAUTH_CLIENT_SECRET"] || System.get_env("DISCORD_OAUTH_CLIENT_SECRET") do
    config :ueberauth, Ueberauth.Strategy.Discord.OAuth,
      client_id: client_id,
      client_secret: client_secret
  end
end

# Discord bot configuration
if discord_token = env["DISCORD_TOKEN"] || System.get_env("DISCORD_TOKEN") do
  config :nostrum, token: discord_token
  config :ddbm_discord, start_bot: true

  # Guild and App IDs for slash command registration
  if guild_id = env["DISCORD_GUILD_ID"] || System.get_env("DISCORD_GUILD_ID") do
    config :ddbm_discord, guild_id: String.to_integer(guild_id)
  end

  if app_id = env["DISCORD_APP_ID"] || System.get_env("DISCORD_APP_ID") do
    config :ddbm_discord, app_id: String.to_integer(app_id)
  end

  # Bot notification channel ID
  if bot_channel_id = env["DISCORD_BOT_CHANNEL"] || System.get_env("DISCORD_BOT_CHANNEL") do
    config :ddbm_discord, bot_channel_id: String.to_integer(bot_channel_id)
  end
end

# Admin Discord IDs configuration
if admin_ids = env["ADMIN_DISCORD_IDS"] || System.get_env("ADMIN_DISCORD_IDS") do
  config :ddbm_web, :admin_discord_ids, admin_ids
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  database_path =
    env["DATABASE_PATH"] || System.get_env("DATABASE_PATH")

  config :ddbm, Ddbm.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    env["SECRET_KEY_BASE"] || System.get_env("SECRET_KEY_BASE")

  config :ddbm_web, DdbmWeb.Endpoint,
    url: [host: "ddbm.smnth.net", port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base,
    server: true

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :ddbm_web, DdbmWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :ddbm_web, DdbmWeb.Endpoint,
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
  #     config :ddbm_web, DdbmWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  config :ddbm, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
end
