defmodule DdbmDiscord.MemberCache do
  @moduledoc """
  GenServer that periodically fetches and caches Discord guild members.
  Syncs on startup and then once per week.

  Member sync process:
  1. Fetches all member IDs via paginated API calls
  2. Checks UserCache for full user data (fast path)
  3. Falls back to REST API for members not in cache
  4. Processes up to 10 members concurrently to balance speed and rate limits
  """

  use GenServer
  require Logger

  alias Nostrum.Api
  alias Nostrum.Api.Guild
  alias Nostrum.Cache.UserCache
  alias Ddbm.Discord

  @sync_interval :timer.hours(24 * 7)

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

    # Fetch full member details, checking UserCache first then falling back to REST API
    members_data =
      all_members
      |> Task.async_stream(
        fn member ->
          fetch_member_data(guild_id, member)
        end,
        max_concurrency: 10,
        timeout: :infinity,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, member_data} -> member_data
        {:exit, _reason} -> nil
      end)
      |> Enum.reject(&is_nil/1)

    # Batch insert all members
    Discord.upsert_members(members_data)

    cached_count = Discord.count_members(guild_id)
    Logger.info("Discord member sync complete. #{cached_count} members cached from #{length(all_members)} total.")

    {:ok, cached_count}
  end

  defp fetch_member_data(guild_id, member) do
    # Try UserCache first (fast)
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
        # Fetch from REST API (slower but complete)
        fetch_member_from_api(guild_id, member.user_id, member.nick)
    end
  end

  defp fetch_member_from_api(guild_id, user_id, _nick) do
    # Fetch guild member to get nickname and other guild-specific data
    with {:ok, member} <- Api.get_guild_member(guild_id, user_id),
         # Get user data - try cache first, then API
         user <- get_user_data(user_id) do
      if user do
        %{
          discord_id: to_string(user.id),
          username: user.username,
          discriminator: user.discriminator,
          display_name: member.nick || user.global_name,
          avatar: user.avatar,
          guild_id: to_string(guild_id)
        }
      else
        nil
      end
    else
      {:error, error} ->
        Logger.debug("Failed to fetch member #{user_id}: #{inspect(error)}")
        nil
    end
  end

  defp get_user_data(user_id) do
    case UserCache.get(user_id) do
      {:ok, user} ->
        user

      {:error, _} ->
        # Not in cache, fetch from API
        case Api.get_user(user_id) do
          {:ok, user} -> user
          {:error, _} -> nil
        end
    end
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
