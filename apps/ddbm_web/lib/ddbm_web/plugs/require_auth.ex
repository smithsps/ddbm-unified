defmodule DdbmWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug to require authentication.

  Redirects unauthenticated users to the home page.
  Must be used after LoadCurrentUser plug.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
