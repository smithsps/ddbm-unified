defmodule DdbmDiscord.Commands.Register do
  @moduledoc """
  Handles the /register command to subscribe users to bot notifications.
  """

  require Logger

  alias DdbmDiscord.Helpers.Interaction, as: Helper

  @bot_notify_role "bot-notify"

  def execute(interaction) do
    guild_id = interaction.guild_id
    user_id = interaction.member.user_id

    with {:ok, role} <- find_role(guild_id),
         :ok <- add_role(guild_id, user_id, role.id) do
      Helper.reply_ephemeral(interaction, "You will now get notifications from #bot-commands.")
    else
      {:error, :role_not_found} ->
        Logger.error("Role '#{@bot_notify_role}' not found in guild #{guild_id}")
        Helper.reply_ephemeral(interaction, "There was an unexpected error, you were not registered.")

      {:error, reason} ->
        Logger.error("Failed to register user #{user_id}: #{inspect(reason)}")
        Helper.reply_ephemeral(interaction, "There was an unexpected error, you were not registered.")
    end
  end

  defp find_role(guild_id) do
    case Nostrum.Cache.GuildCache.get(guild_id) do
      {:ok, guild} ->
        role = Enum.find(guild.roles, fn {_id, role} -> role.name == @bot_notify_role end)

        case role do
          {_id, role} -> {:ok, role}
          nil -> {:error, :role_not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_role(guild_id, user_id, role_id) do
    case Nostrum.Api.Guild.add_member_role(guild_id, user_id, role_id) do
      {:ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
