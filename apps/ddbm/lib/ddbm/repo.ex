defmodule Ddbm.Repo do
  use Ecto.Repo,
    otp_app: :ddbm,
    adapter: Ecto.Adapters.SQLite3
end
