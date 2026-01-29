defmodule Ddbm.Discord do
  @moduledoc """
  Context for managing cached Discord member information.
  """

  import Ecto.Query
  alias Ddbm.Repo
  alias Ddbm.Discord.Member

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
end
