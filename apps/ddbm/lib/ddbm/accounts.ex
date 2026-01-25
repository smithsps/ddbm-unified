defmodule Ddbm.Accounts do
  @moduledoc """
  The Accounts context for managing users.
  """

  import Ecto.Query, warn: false
  alias Ddbm.Repo
  alias Ddbm.Accounts.User

  @doc """
  Gets a user by Discord ID.

  Returns `nil` if the user doesn't exist.

  ## Examples

      iex> get_user_by_discord_id("123456789")
      %User{}

      iex> get_user_by_discord_id("nonexistent")
      nil

  """
  def get_user_by_discord_id(discord_id) do
    Repo.get_by(User, discord_id: discord_id)
  end

  @doc """
  Gets a user by ID.

  Returns `nil` if the user doesn't exist.
  """
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Creates or updates a user from Discord OAuth data.

  ## Examples

      iex> create_or_update_user_from_discord(%{discord_id: "123", discord_username: "user"})
      {:ok, %User{}}

  """
  def create_or_update_user_from_discord(attrs) do
    case get_user_by_discord_id(attrs.discord_id) do
      nil ->
        %User{}
        |> User.create_changeset(attrs)
        |> Repo.insert()

      user ->
        user
        |> User.update_changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates the last login timestamp for a user.

  ## Examples

      iex> update_last_login(user)
      {:ok, %User{}}

  """
  def update_last_login(%User{} = user) do
    user
    |> User.update_changeset(%{last_login_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Searches for users by username (case-insensitive partial match).

  ## Examples

      iex> search_users_by_username("john")
      [%User{discord_username: "john_doe"}, %User{discord_username: "johnny"}]

  """
  def search_users_by_username(query) when is_binary(query) do
    search_pattern = "%#{query}%"

    from(u in User,
      where: ilike(u.discord_username, ^search_pattern),
      order_by: [asc: u.discord_username],
      limit: 10
    )
    |> Repo.all()
  end

  def search_users_by_username(_), do: []

  @doc """
  Lists all users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end
end
