defmodule Ddbm.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :discord_id, :string
    field :discord_username, :string
    field :discord_discriminator, :string
    field :discord_avatar, :string
    field :discord_email, :string
    field :access_token_hash, :string
    field :refresh_token_hash, :string
    field :token_expires_at, :utc_datetime
    field :last_login_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a user from Discord OAuth data.
  """
  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :discord_id,
      :discord_username,
      :discord_discriminator,
      :discord_avatar,
      :discord_email,
      :access_token_hash,
      :refresh_token_hash,
      :token_expires_at,
      :last_login_at
    ])
    |> validate_required([:discord_id, :discord_username])
    |> unique_constraint(:discord_id)
  end

  @doc """
  Changeset for updating user OAuth tokens and profile data.
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :discord_username,
      :discord_discriminator,
      :discord_avatar,
      :discord_email,
      :access_token_hash,
      :refresh_token_hash,
      :token_expires_at,
      :last_login_at
    ])
  end

  @doc """
  Hashes an OAuth token for secure storage.
  """
  def hash_token(token) when is_binary(token) do
    :crypto.hash(:sha256, token) |> Base.encode64()
  end

  def hash_token(_), do: nil
end
