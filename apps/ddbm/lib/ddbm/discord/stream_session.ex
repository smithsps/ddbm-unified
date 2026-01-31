defmodule Ddbm.Discord.StreamSession do
  @moduledoc """
  Schema for tracking Discord member streaming sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "stream_sessions" do
    field :discord_id, :string
    field :guild_id, :string
    field :stream_url, :string
    field :stream_name, :string
    field :game_name, :string
    field :platform, :string
    field :details, :string
    field :state, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(stream_session, attrs) do
    stream_session
    |> cast(attrs, [
      :discord_id,
      :guild_id,
      :stream_url,
      :stream_name,
      :game_name,
      :platform,
      :details,
      :state,
      :started_at,
      :ended_at
    ])
    |> validate_required([:discord_id, :guild_id, :started_at])
  end
end
