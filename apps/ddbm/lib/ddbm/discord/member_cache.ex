defmodule Ddbm.Discord.MemberCache do
  @moduledoc """
  ETS-based cache for Discord member display names.
  Provides fast lookups with automatic database fallback.
  """

  use GenServer
  require Logger

  @table_name :discord_member_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    # Create ETS table with read_concurrency for fast lookups
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])

    Logger.info("Discord member cache initialized")

    {:ok, %{}}
  end

  @doc """
  Gets a display name from cache, with automatic database fallback.
  Returns the display name string or the discord_id if not found.
  """
  def get_display_name(discord_id, guild_id) do
    key = {to_string(discord_id), to_string(guild_id)}

    case :ets.lookup(@table_name, key) do
      [{^key, display_name}] ->
        # Cache hit
        display_name

      [] ->
        # Cache miss - check database and cache result
        case Ddbm.Discord.get_member(discord_id, guild_id) do
          nil ->
            # Not in database either, return ID
            to_string(discord_id)

          member ->
            # Found in database, compute display name and cache it
            display_name = compute_display_name(member)
            :ets.insert(@table_name, {key, display_name})
            display_name
        end
    end
  end

  @doc """
  Gets avatar URL from cache, with automatic database fallback.
  Returns the full Discord CDN avatar URL or nil if not found.
  """
  def get_avatar(discord_id, guild_id) do
    case Ddbm.Discord.get_member(discord_id, guild_id) do
      nil ->
        nil

      member ->
        if member.avatar do
          "https://cdn.discordapp.com/avatars/#{member.discord_id}/#{member.avatar}.png"
        else
          nil
        end
    end
  end

  @doc """
  Puts a member into the cache.
  Called when we upsert a member to the database.
  """
  def put_member(member) do
    key = {to_string(member.discord_id), to_string(member.guild_id)}
    display_name = compute_display_name(member)
    :ets.insert(@table_name, {key, display_name})
    :ok
  end

  @doc """
  Clears all cached members for a guild.
  """
  def clear_guild(guild_id) do
    guild_id_str = to_string(guild_id)

    :ets.select_delete(@table_name, [
      {{{:"$1", :"$2"}, :_}, [{:==, :"$2", guild_id_str}], [true]}
    ])

    :ok
  end

  @doc """
  Clears the entire cache.
  """
  def clear_all do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  defp compute_display_name(member) do
    cond do
      member.display_name && member.display_name != "" ->
        member.display_name

      member.discriminator && member.discriminator != "0" ->
        "#{member.username}##{member.discriminator}"

      member.username ->
        member.username

      true ->
        member.discord_id
    end
  end
end
