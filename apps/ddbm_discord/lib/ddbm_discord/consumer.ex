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
  def handle_event({:PRESENCE_UPDATE, {guild_id, _old_presence, new_presence}, _ws_state}) do
    # Track streaming activity
    handle_presence_update(guild_id, new_presence)
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
    alias Nostrum.Api.Guild

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
        case Guild.member(guild_id, member.user_id) do
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

  defp handle_presence_update(guild_id, presence) do
    # Presence updates contain activities which include streaming info
    # Activity type 1 = Streaming
    user_id = presence.user.id

    streaming_activity =
      Enum.find(presence.activities || [], fn activity ->
        activity.type == 1
      end)

    is_currently_streaming = Discord.streaming?(user_id, guild_id)

    case {streaming_activity, is_currently_streaming} do
      {nil, true} ->
        # User stopped streaming
        Discord.end_stream(user_id, guild_id)
        Logger.info("User #{user_id} stopped streaming in guild #{guild_id}")

      {activity, false} when not is_nil(activity) ->
        attrs = %{
          discord_id: to_string(user_id),
          guild_id: to_string(guild_id),
          stream_url: activity.url,
          stream_name: activity.name,
          game_name: activity.name,
          platform: extract_platform(activity.url),
          details: activity.details,
          state: activity.state,
          started_at: extract_timestamp(activity) || DateTime.utc_now()
        }

        Discord.start_stream(attrs)
        Logger.info("User #{user_id} started streaming in guild #{guild_id}: #{activity.name}")

      {activity, true} when not is_nil(activity) ->
        # User is still streaming and we have a record
        # This is normal - they're continuing to stream
        # We could update stream details here if they changed (e.g., switched games)
        :noop

      _ ->
        # No streaming activity detected
        :noop
    end
  end

  defp extract_platform(nil), do: "discord"

  defp extract_platform(url) do
    cond do
      String.contains?(url, "twitch.tv") -> "twitch"
      String.contains?(url, "youtube.com") or String.contains?(url, "youtu.be") -> "youtube"
      true -> "discord"
    end
  end

  defp extract_timestamp(activity) do
    case activity.timestamps do
      %{start: start_ms} when is_integer(start_ms) ->
        DateTime.from_unix!(start_ms, :millisecond)

      _ ->
        nil
    end
  end
end
