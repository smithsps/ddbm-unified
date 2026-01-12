defmodule DdbmDiscord.CommandSyncer do
  @moduledoc """
  GenServer that registers slash commands with Discord on startup.
  """

  use GenServer
  require Logger

  alias Nostrum.Api.ApplicationCommand

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Delay command registration to ensure bot is connected
    Process.send_after(self(), :sync_commands, 5_000)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sync_commands, state) do
    sync_commands()
    {:noreply, state}
  end

  defp sync_commands do
    guild_id = Application.get_env(:ddbm_discord, :guild_id)

    if guild_id do
      commands = DdbmDiscord.Commands.all()

      Logger.info("Syncing #{length(commands)} slash commands to guild #{guild_id}...")

      case ApplicationCommand.bulk_overwrite_guild_commands(guild_id, commands) do
        {:ok, registered} ->
          Logger.info("Successfully registered #{length(registered)} slash commands")

        {:error, error} ->
          Logger.error("Failed to register slash commands: #{inspect(error)}")
      end
    else
      Logger.warning("DISCORD_GUILD_ID not configured, skipping slash command registration")
    end
  end
end
