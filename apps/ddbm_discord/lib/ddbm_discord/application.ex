defmodule DdbmDiscord.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:ddbm_discord, :start_bot, true) do
        IO.puts("\n==> Starting Discord bot...")

        [
          DdbmDiscord.Consumer,
          DdbmDiscord.CommandSyncer
        ]
      else
        []
      end

    opts = [strategy: :one_for_one, name: DdbmDiscord.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
