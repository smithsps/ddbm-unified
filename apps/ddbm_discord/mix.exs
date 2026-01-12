defmodule DdbmDiscord.MixProject do
  use Mix.Project

  def project do
    [
      app: :ddbm_discord,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {DdbmDiscord.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nostrum, "~> 0.10", runtime: Mix.env() == :prod},
      {:dotenvy, "~> 0.9"},
      {:ddbm, in_umbrella: true}
    ]
  end
end
