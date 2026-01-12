defmodule Ddbm.Tokens.Transaction do
  @moduledoc """
  Schema for token transactions between Discord users.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :user_id, :string
    field :sender_user_id, :string
    field :token, :string
    field :amount, :integer
    field :source, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:user_id, :sender_user_id, :token, :amount, :source])
    |> validate_required([:user_id, :amount])
    |> validate_number(:amount, greater_than: 0)
  end
end
