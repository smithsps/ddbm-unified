defmodule Ddbm.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :discord_id, :string, null: false
      add :discord_username, :string, null: false
      add :discord_discriminator, :string
      add :discord_avatar, :string
      add :discord_email, :string
      add :access_token_hash, :string
      add :refresh_token_hash, :string
      add :token_expires_at, :utc_datetime
      add :last_login_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:discord_id])
  end
end
