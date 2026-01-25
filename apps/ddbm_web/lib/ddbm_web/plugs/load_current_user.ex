defmodule DdbmWeb.Plugs.LoadCurrentUser do
  @moduledoc """
  Plug to load the current user from the session into assigns.

  If a user_id is present in the session, loads the user from the database
  and assigns it to conn.assigns.current_user. Otherwise, assigns nil.
  """

  import Plug.Conn
  alias Ddbm.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    cond do
      # If user is already loaded, skip
      Map.has_key?(conn.assigns, :current_user) ->
        conn

      # If user_id in session, load user
      user_id ->
        user = Accounts.get_user(user_id)
        assign(conn, :current_user, user)

      # No user_id in session
      true ->
        assign(conn, :current_user, nil)
    end
  end
end
