defmodule DdbmWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :ddbm_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {DdbmWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:ddbm, in_umbrella: true},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_discord, "~> 0.7"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["cmd --cd assets npm install"],
      "assets.build": ["compile", "cmd --cd assets npm run build"],
      "assets.deploy": [
        "compile",
        "cmd --cd assets npm run deploy",
        "phx.digest"
      ],
      "assets.deploy.nix": [
        "compile",
        "cmd --cd assets npx tailwindcss --input=css/app.css --output=../priv/static/assets/css/app.css --minify",
        "cmd --cd assets NODE_PATH=../../../_build/prod:../../../deps npx esbuild js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=. --minify",
        "phx.digest"
      ]
    ]
  end
end
