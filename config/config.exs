# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :ddbm,
  ecto_repos: [Ddbm.Repo]

config :ddbm_web,
  ecto_repos: [Ddbm.Repo],
  generators: [context_app: :ddbm]

# Configures the endpoint
config :ddbm_web, DdbmWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DdbmWeb.ErrorHTML, json: DdbmWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Ddbm.PubSub,
  live_view: [signing_salt: "R3a6z6Nf"]

# Configure esbuild
# Nix builds provide the binary via deps.nix override, preventing downloads
config :esbuild,
  version: "0.25.0",
  version_check: false,
  path: Path.expand("../deps/esbuild/bin/esbuild", __DIR__),
  ddbm_web: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/ddbm_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind
# Nix builds provide the binary via deps.nix override, preventing downloads
config :tailwind,
  version: "4.1.12",
  version_check: false,
  path: Path.expand("../deps/tailwind/bin/tailwindcss", __DIR__),
  ddbm_web: [
    args: ~w(--input=css/app.css --output=../priv/static/assets/css/app.css),
    cd: Path.expand("../apps/ddbm_web/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Ueberauth OAuth configuration
# OAuth credentials are configured in runtime.exs to load from .env
config :ueberauth, Ueberauth,
  providers: [
    discord: {Ueberauth.Strategy.Discord, []}
  ]

# Nostrum Discord bot configuration
config :nostrum,
  gateway_intents: [
    :guilds,
    :guild_messages,
    :message_content,
    :direct_messages
  ],
  ffmpeg: nil

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
