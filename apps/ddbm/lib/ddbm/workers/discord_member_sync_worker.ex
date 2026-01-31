defmodule Ddbm.Workers.DiscordMemberSyncWorker do
  @moduledoc """
  Oban worker that periodically fetches and caches Discord guild members.

  Member sync process:
  1. Fetches all member IDs via paginated API calls
  2. Checks UserCache for full user data (fast path)
  3. Falls back to REST API for members not in cache
  4. Processes up to 10 members concurrently to balance speed and rate limits
  """

  use Oban.Worker,
    queue: :discord,
    max_attempts: 3,
    unique: [period: {7, :days}]

  require Logger
  alias Nostrum.Api
  alias Nostrum.Api.Guild
  alias Nostrum.Cache.UserCache
  alias Ddbm.Discord

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"guild_id" => guild_id}}) do
    Logger.info("Starting Oban Discord member sync for guild #{guild_id}")

    guild_id = String.to_integer(guild_id)

    case sync_guild_members(guild_id) do
      {:ok, count} ->
        Logger.info("Discord member sync complete. #{count} members cached.")
        :ok

      {:error, reason} ->
        Logger.error("Discord member sync failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp sync_guild_members(guild_id) do
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
