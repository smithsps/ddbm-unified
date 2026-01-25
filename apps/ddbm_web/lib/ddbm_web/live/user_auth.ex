defmodule DdbmWeb.UserAuth do
  @moduledoc """
  LiveView authentication hooks.
  """

  import Phoenix.LiveView
  import Phoenix.Component
  alias Ddbm.Accounts

  use Phoenix.VerifiedRoutes,
    endpoint: DdbmWeb.Endpoint,
    router: DdbmWeb.Router,
    statics: DdbmWeb.static_paths()

  @doc """
  On mount hook that loads the current user from the session.

  Use in router.ex with live_session:

      live_session :authenticated,
        on_mount: [DdbmWeb.UserAuth] do
        live "/dashboard", DashboardLive
      end
  """
  def on_mount(:default, _params, session, socket) do
    socket = mount_current_user(socket, session)

    {:cont, socket}
  end

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  defp mount_current_user(socket, session) do
    case session do
      %{"user_id" => user_id} ->
        user = Accounts.get_user(user_id)
        assign(socket, :current_user, user)

      _ ->
        assign(socket, :current_user, nil)
    end
  end
end
