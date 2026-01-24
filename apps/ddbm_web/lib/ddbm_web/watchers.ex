defmodule DdbmWeb.Watchers do
  @moduledoc """
  Helper module for running asset watchers for local development.
  I could not get config :ddbm_web, DdbmWeb.Endpoint, :watchers to work for the life of me.
  """

  require Logger

  def esbuild do
    assets_dir = Path.expand("../../assets", __DIR__)
    esbuild_path = Path.join([assets_dir, "node_modules", "esbuild", "bin", "esbuild"])

    args = [
      "js/app.js",
      "--bundle",
      "--target=es2022",
      "--outdir=../priv/static/assets/js",
      "--external:/fonts/*",
      "--external:/images/*",
      "--alias:@=.",
      "--watch"
    ]

    opts = [
      cd: assets_dir,
      env: %{"NODE_PATH" => "../../../_build/dev:../../../deps"},
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    ]

    Logger.info("Starting esbuild watcher from #{assets_dir}")
    Logger.debug("Running: #{esbuild_path} #{Enum.join(args, " ")}")

    case System.cmd(esbuild_path, args, opts) do
      {_, 0} -> :ok
      {_, code} ->
        Logger.error("esbuild exited with code #{code}")
        Process.sleep(2000)
        exit(:watcher_command_error)
    end
  end

  def tailwind do
    assets_dir = Path.expand("../../assets", __DIR__)
    tailwind_path = Path.join([assets_dir, "node_modules", "@tailwindcss", "cli", "dist", "index.mjs"])

    args = [
      "-i",
      "css/app.css",
      "-o",
      "../priv/static/assets/css/app.css",
      "--watch"
    ]

    opts = [
      cd: assets_dir,
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    ]

    Logger.info("Starting tailwind watcher from #{assets_dir}")
    Logger.debug("Running: node #{tailwind_path} #{Enum.join(args, " ")}")

    case System.cmd("node", [tailwind_path | args], opts) do
      {_, 0} -> :ok
      {_, code} ->
        Logger.error("tailwind exited with code #{code}")
        Process.sleep(2000)
        exit(:watcher_command_error)
    end
  end
end
