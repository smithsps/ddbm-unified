defmodule Ddbm.Repo.Migrations.CreateDiscordMembers do
  use Ecto.Migration

  def change do
    create table(:discord_members) do
      add :discord_id, :string, null: false
      add :username, :string, null: false
      add :discriminator, :string
      add :display_name, :string
      add :avatar, :string
      add :guild_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:discord_members, [:discord_id, :guild_id])
    create index(:discord_members, [:guild_id])
  end
end
