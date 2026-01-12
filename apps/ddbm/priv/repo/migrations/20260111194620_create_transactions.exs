defmodule Ddbm.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :user_id, :string, null: false
      add :sender_user_id, :string
      add :token, :string
      add :amount, :integer, null: false
      add :source, :string

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:user_id])
    create index(:transactions, [:sender_user_id])
    create index(:transactions, [:token])
  end
end
