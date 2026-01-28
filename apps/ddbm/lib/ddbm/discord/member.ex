defmodule Ddbm.Discord.Member do
  @moduledoc """
  Schema for cached Discord server member information.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "discord_members" do
    field :discord_id, :string
    field :username, :string
    field :discriminator, :string
    field :display_name, :string
    field :avatar, :string
    field :guild_id, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(member, attrs) do
    member
    |> cast(attrs, [:discord_id, :username, :discriminator, :display_name, :avatar, :guild_id])
    |> validate_required([:discord_id, :username, :guild_id])
    |> unique_constraint([:discord_id, :guild_id])
  end
end
