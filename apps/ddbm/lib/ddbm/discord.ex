defmodule Ddbm.Discord do
  @moduledoc """
  Context for managing cached Discord member information.
  """

  import Ecto.Query
  alias Ddbm.Repo
  alias Ddbm.Discord.{Member, StreamSession}

  @doc """
  Gets a Discord member by their Discord ID and guild ID.
  Returns nil if not found in cache.
  """
  def get_member(discord_id, guild_id) do
    Repo.get_by(Member, discord_id: to_string(discord_id), guild_id: to_string(guild_id))
  end

  @doc """
  Gets display name for a Discord user, with ETS cache and database fallback.
  Tries: display_name > username#discriminator > username > discord_id
  """
  def get_display_name(discord_id, guild_id) do
    Ddbm.Discord.MemberCache.get_display_name(discord_id, guild_id)
  end

  @doc """
  Gets avatar URL for a Discord user from the cache/database.
  Returns nil if not found.
  """
  def get_avatar(discord_id, guild_id) do
    Ddbm.Discord.MemberCache.get_avatar(discord_id, guild_id)
  end

  @doc """
  Upserts a Discord member into the database and ETS cache.
  """
  def upsert_member(attrs) do
    discord_id = to_string(attrs.discord_id || attrs[:discord_id])
    guild_id = to_string(attrs.guild_id || attrs[:guild_id])

    result =
      case get_member(discord_id, guild_id) do
        nil ->
          %Member{}
          |> Member.changeset(attrs)
          |> Repo.insert()

        member ->
          member
          |> Member.changeset(attrs)
          |> Repo.update()
      end

    # Update ETS cache on success
    case result do
      {:ok, member} ->
        Ddbm.Discord.MemberCache.put_member(member)
        {:ok, member}

      error ->
        error
    end
  end

  @doc """
  Upserts multiple Discord members at once.
  """
  def upsert_members(members_list) do
    Enum.each(members_list, &upsert_member/1)
  end

  @doc """
  Returns all cached members for a guild.
  """
  def list_members(guild_id) do
    Member
    |> where([m], m.guild_id == ^to_string(guild_id))
    |> Repo.all()
  end

  @doc """
  Deletes all cached members for a guild from database and ETS cache.
  Useful for refreshing the cache.
  """
  def delete_guild_members(guild_id) do
    result =
      Member
      |> where([m], m.guild_id == ^to_string(guild_id))
      |> Repo.delete_all()

    Ddbm.Discord.MemberCache.clear_guild(guild_id)
    result
  end

  @doc """
  Returns the count of cached members for a guild.
  """
  def count_members(guild_id) do
    Member
    |> where([m], m.guild_id == ^to_string(guild_id))
    |> Repo.aggregate(:count)
  end

  @doc """
  Searches for Discord members by username or display name.
  Returns up to 10 results ordered by username with avatar URLs.
  """
  def search_members(query, guild_id) when is_binary(query) do
    search_pattern = "%#{query}%"

    from(m in Member,
      where: m.guild_id == ^to_string(guild_id),
      where: like(m.username, ^search_pattern) or like(m.display_name, ^search_pattern),
      order_by: [asc: m.username],
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(&add_avatar_url/1)
  end

  def search_members(_query, _guild_id), do: []

  @doc """
  Adds avatar_url field to a Discord member.
  """
  def add_avatar_url(%Member{} = member) do
    avatar_url =
      if member.avatar do
        "https://cdn.discordapp.com/avatars/#{member.discord_id}/#{member.avatar}.png"
      else
        # Default Discord avatar based on discriminator
        discriminator = String.to_integer(member.discriminator || "0")
        index = rem(discriminator, 5)
        "https://cdn.discordapp.com/embed/avatars/#{index}.png"
      end

    Map.put(member, :avatar_url, avatar_url)
  end

  # Stream Session Management

  @doc """
  Starts a new streaming session for a Discord user.
  """
  def start_stream(attrs) do
    %StreamSession{}
    |> StreamSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Ends an active streaming session for a Discord user.
  Sets the ended_at timestamp for the most recent active stream.
  """
  def end_stream(discord_id, guild_id) do
    StreamSession
    |> where([s], s.discord_id == ^to_string(discord_id))
    |> where([s], s.guild_id == ^to_string(guild_id))
    |> where([s], is_nil(s.ended_at))
    |> order_by([s], desc: s.started_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil ->
        {:ok, nil}

      session ->
        session
        |> StreamSession.changeset(%{ended_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  @doc """
  Gets all currently active streams for a guild.
  Returns streams that have started_at but no ended_at.
  """
  def get_active_streams(guild_id) do
    StreamSession
    |> where([s], s.guild_id == ^to_string(guild_id))
    |> where([s], is_nil(s.ended_at))
    |> order_by([s], desc: s.started_at)
    |> Repo.all()
  end

  @doc """
  Gets stream history for a specific user in a guild.
  Returns completed streams ordered by most recent first.
  Accepts optional limit (defaults to 50).
  """
  def get_stream_history(discord_id, guild_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    StreamSession
    |> where([s], s.discord_id == ^to_string(discord_id))
    |> where([s], s.guild_id == ^to_string(guild_id))
    |> where([s], not is_nil(s.ended_at))
    |> order_by([s], desc: s.started_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets all stream history for a guild.
  Returns all completed streams ordered by most recent first.
  Accepts optional limit (defaults to 100).
  """
  def get_guild_stream_history(guild_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    StreamSession
    |> where([s], s.guild_id == ^to_string(guild_id))
    |> where([s], not is_nil(s.ended_at))
    |> order_by([s], desc: s.started_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets streaming statistics for a user.
  Returns total streams, total time streamed, and average stream duration.
  """
  def get_user_stream_stats(discord_id, guild_id) do
    sessions =
      StreamSession
      |> where([s], s.discord_id == ^to_string(discord_id))
      |> where([s], s.guild_id == ^to_string(guild_id))
      |> where([s], not is_nil(s.ended_at))
      |> Repo.all()

    total_streams = length(sessions)

    total_seconds =
      sessions
      |> Enum.map(fn session ->
        DateTime.diff(session.ended_at, session.started_at, :second)
      end)
      |> Enum.sum()

    avg_seconds =
      if total_streams > 0 do
        div(total_seconds, total_streams)
      else
        0
      end

    %{
      total_streams: total_streams,
      total_seconds: total_seconds,
      average_seconds: avg_seconds
    }
  end

  @doc """
  Checks if a user is currently streaming in a guild.
  """
  def streaming?(discord_id, guild_id) do
    StreamSession
    |> where([s], s.discord_id == ^to_string(discord_id))
    |> where([s], s.guild_id == ^to_string(guild_id))
    |> where([s], is_nil(s.ended_at))
    |> Repo.exists?()
  end
end
