defmodule Ddbm.Repo.Migrations.CreateStreamSessions do
  use Ecto.Migration

  def change do
    create table(:stream_sessions) do
      add :discord_id, :string, null: false
      add :guild_id, :string, null: false
      add :stream_url, :string
      add :stream_name, :string
      add :game_name, :string
      add :platform, :string
      add :details, :string
      add :state, :string
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:stream_sessions, [:discord_id])
    create index(:stream_sessions, [:guild_id])
    create index(:stream_sessions, [:started_at])
    create index(:stream_sessions, [:discord_id, :guild_id])
  end
end
