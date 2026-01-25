defmodule DdbmWeb.AuthController do
  @moduledoc """
  Handles Discord OAuth authentication.
  """

  use DdbmWeb, :controller
  plug Ueberauth

  alias Ddbm.Accounts

  @doc """
  Initiates the OAuth flow.
  This is handled automatically by Ueberauth.
  """
  def request(conn, _params) do
    # Ueberauth handles the redirect to Discord
    conn
  end

  @doc """
  Handles the OAuth callback from Discord.
  Creates or updates the user and sets up the session.
  """
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = prepare_user_params(auth)

    case Accounts.create_or_update_user_from_discord(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome, #{user.discord_username}!")
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: ~p"/dashboard")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to authenticate. Please try again.")
        |> redirect(to: ~p"/")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate with Discord.")
    |> redirect(to: ~p"/")
  end

  @doc """
  Logs out the current user.
  """
  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: ~p"/")
  end

  # Private functions

  defp prepare_user_params(auth) do
    alias Ddbm.Accounts.User

    %{
      discord_id: auth.uid,
      discord_username: get_in(auth.extra.raw_info.user, ["username"]) ||
                        get_in(auth.extra.raw_info.user, ["global_name"]) ||
                        "Unknown",
      discord_discriminator: get_in(auth.extra.raw_info.user, ["discriminator"]),
      discord_avatar: auth.info.image,
      discord_email: auth.info.email,
      access_token_hash: User.hash_token(auth.credentials.token),
      refresh_token_hash: User.hash_token(auth.credentials.refresh_token),
      token_expires_at: parse_expires_at(auth.credentials.expires_at),
      last_login_at: DateTime.utc_now()
    }
  end

  defp parse_expires_at(nil), do: nil

  defp parse_expires_at(unix_timestamp) when is_integer(unix_timestamp) do
    DateTime.from_unix!(unix_timestamp)
  end

  defp parse_expires_at(_), do: nil
end
