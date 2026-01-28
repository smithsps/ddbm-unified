defmodule DdbmDiscord.MemberCache do
  @moduledoc """
  GenServer that periodically fetches and caches Discord guild members.
  Syncs on startup and then every hour.
  """

  use GenServer
  require Logger

  alias Nostrum.Api.Guild
  alias Nostrum.Cache.UserCache
  alias Ddbm.Discord

  @sync_interval :timer.hours(1)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    # Schedule immediate sync on startup
    send(self(), :sync_members)

    {:ok, %{last_sync: nil}}
  end

  @impl true
  def handle_info(:sync_members, state) do
    guild_id = Application.get_env(:ddbm_discord, :guild_id)

    if guild_id do
      sync_guild_members(guild_id)

      # Schedule next sync
      Process.send_after(self(), :sync_members, @sync_interval)

      {:noreply, %{state | last_sync: DateTime.utc_now()}}
    else
      Logger.warning("No guild_id configured, skipping member sync")
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:force_sync, _from, state) do
    guild_id = Application.get_env(:ddbm_discord, :guild_id)

    if guild_id do
      result = sync_guild_members(guild_id)
      {:reply, result, %{state | last_sync: DateTime.utc_now()}}
    else
      {:reply, {:error, :no_guild_configured}, state}
    end
  end

  @doc """
  Forces an immediate sync of guild members.
  """
  def force_sync do
    GenServer.call(__MODULE__, :force_sync, 30_000)
  end

  defp sync_guild_members(guild_id) do
    Logger.info("Starting Discord member sync for guild #{guild_id}")

    all_members = fetch_all_members(guild_id, [], nil)
    Logger.info("Fetched #{length(all_members)} total members from Discord")

    # Only cache members that are in Nostrum's UserCache
    # Others will be cached naturally as they interact with the bot
    members_data =
      all_members
      |> Enum.map(fn member ->
        case UserCache.get(member.user_id) do
          {:ok, user} ->
            %{
              discord_id: to_string(user.id),
              username: user.username,
              discriminator: user.discriminator,
              display_name: member.nick || user.global_name,
              avatar: user.avatar,
              guild_id: to_string(guild_id)
            }

          {:error, _} ->
            # Not in cache yet, will be cached when they interact
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    Discord.upsert_members(members_data)

    cached_count = Discord.count_members(guild_id)
    Logger.info("Discord member sync complete. #{cached_count} members cached from #{length(all_members)} total.")

    {:ok, cached_count}
  end

  defp fetch_all_members(guild_id, accumulated, after_id) do
    opts = [limit: 1000]
    opts = if after_id, do: Keyword.put(opts, :after, after_id), else: opts

    case Guild.members(guild_id, opts) do
      {:ok, members} when length(members) < 1000 ->
        # Last page
        accumulated ++ members

      {:ok, members} ->
        # More pages to fetch
        last_user_id = List.last(members).user_id
        Logger.debug("Fetched batch of #{length(members)}, continuing from #{last_user_id}")
        fetch_all_members(guild_id, accumulated ++ members, last_user_id)

      {:error, error} ->
        Logger.error("Failed to fetch guild members: #{inspect(error)}")
        accumulated
    end
  end
end
