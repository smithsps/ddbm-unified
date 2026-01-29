defmodule DdbmDiscord.Consumer do
  @moduledoc """
  Handles Discord gateway events from Nostrum.
  """

  use Nostrum.Consumer
  require Logger

  alias DdbmDiscord.Commands.{Give, Token, TokenAdmin, Register, Unregister}
  alias Ddbm.Discord

  @impl true
  def handle_event({:READY, data, _ws_state}) do
    Logger.info("Discord bot connected as #{data.user.username}")
  end

  @impl true
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    # Cache the user who triggered the interaction
    cache_interaction_user(interaction)

    handle_interaction(interaction)
  end

  @impl true
  def handle_event({:GUILD_MEMBER_UPDATE, {guild_id, _old_member, new_member}, _ws_state}) do
    # Cache member updates in real-time (username, avatar, nickname changes)
    cache_member_update(guild_id, new_member)
  end

  @impl true
  def handle_event(_event) do
    :noop
  end

  defp handle_interaction(%{data: %{name: "give"}} = interaction) do
    Give.execute(interaction)
  end

  defp handle_interaction(%{data: %{name: "token"}} = interaction) do
    Token.execute(interaction)
  end

  defp handle_interaction(%{data: %{name: "token-admin"}} = interaction) do
    TokenAdmin.execute(interaction)
  end

  defp handle_interaction(%{data: %{name: "register"}} = interaction) do
    Register.execute(interaction)
  end

  defp handle_interaction(%{data: %{name: "unregister"}} = interaction) do
    Unregister.execute(interaction)
  end

  defp handle_interaction(interaction) do
    Logger.warning("Unknown command: #{inspect(interaction.data.name)}")
  end

  defp cache_interaction_user(interaction) do
    if interaction.user && interaction.guild_id do
      user = interaction.user
      member = interaction.member

      attrs = %{
        discord_id: to_string(user.id),
        username: user.username,
        discriminator: user.discriminator,
        display_name: (member && member.nick) || user.global_name,
        avatar: user.avatar,
        guild_id: to_string(interaction.guild_id)
      }

      Discord.upsert_member(attrs)
    end
  end

  defp cache_member_update(guild_id, member) do
    # Member struct only has user_id, need to get full user from cache or API
    alias Nostrum.Cache.UserCache
    alias Nostrum.Api

    case UserCache.get(member.user_id) do
      {:ok, user} ->
        attrs = %{
          discord_id: to_string(user.id),
          username: user.username,
          discriminator: user.discriminator,
          display_name: member.nick || user.global_name,
          avatar: user.avatar,
          guild_id: to_string(guild_id)
        }

        Discord.upsert_member(attrs)

      {:error, _} ->
        # User not in cache, fetch from API
        case Api.get_guild_member(guild_id, member.user_id) do
          {:ok, full_member} ->
            user = full_member.user

            attrs = %{
              discord_id: to_string(user.id),
              username: user.username,
              discriminator: user.discriminator,
              display_name: full_member.nick || user.global_name,
              avatar: user.avatar,
              guild_id: to_string(guild_id)
            }

            Discord.upsert_member(attrs)

          {:error, _} ->
            # Failed to fetch, skip this update
            :ok
        end
    end
  end
end
