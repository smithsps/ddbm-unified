defmodule DdbmWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use DdbmWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :map, default: nil, doc: "the current authenticated user"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if assigns[:current_user] do %>
      <header class="sticky top-0 z-50 bg-gray-900/95 backdrop-blur-sm border-b border-white/10">
        <nav class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <%!-- Logo --%>
            <div class="flex items-center gap-6">
              <.link navigate="/" class="flex items-center gap-2 text-white hover:text-purple-400 transition-colors">
                <img src={~p"/images/logo.svg"} width="32" class="brightness-0 invert" />
                <span class="text-xl font-bold">DDBM</span>
              </.link>

              <%!-- Navigation Links (Desktop) --%>
              <div class="hidden md:flex items-center gap-1">
                <.nav_link navigate="/dashboard" icon="hero-home">Dashboard</.nav_link>
                <.nav_link navigate="/tokens" icon="hero-trophy">Tokens</.nav_link>
                <.nav_link navigate="/transactions" icon="hero-list-bullet">Transactions</.nav_link>
                <.nav_link navigate="/give" icon="hero-gift">Give</.nav_link>
              </div>
            </div>

            <%!-- Right Side --%>
            <div class="flex items-center gap-4">
              <%!-- User Menu --%>
              <div class="relative group">
                <button class="flex items-center gap-2 px-3 py-2 rounded-lg bg-white/5 hover:bg-white/10 transition-colors">
                  <.user_avatar user={@current_user} size="sm" />
                  <span class="hidden sm:block text-sm font-medium text-white">
                    {@current_user.discord_username}
                  </span>
                  <.icon name="hero-chevron-down" class="w-4 h-4 text-gray-400" />
                </button>

                <%!-- Dropdown Menu --%>
                <div class="absolute right-0 mt-2 w-48 rounded-lg bg-gray-800 border border-white/10 shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all">
                  <div class="p-2">
                    <.link
                      href="/logout"
                      method="delete"
                      class="flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-white/10 rounded-lg transition-colors"
                    >
                      <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" />
                      Logout
                    </.link>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Mobile Navigation --%>
          <div class="md:hidden border-t border-white/10 py-3">
            <div class="flex flex-col gap-1">
              <.nav_link navigate="/dashboard" icon="hero-home">Dashboard</.nav_link>
              <.nav_link navigate="/tokens" icon="hero-trophy">Tokens</.nav_link>
              <.nav_link navigate="/transactions" icon="hero-list-bullet">Transactions</.nav_link>
              <.nav_link navigate="/give" icon="hero-gift">Give</.nav_link>
            </div>
          </div>
        </nav>
      </header>
    <% end %>

    <main class="min-h-screen bg-gradient-to-b from-gray-900 to-black">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Navigation link component.
  """
  attr :navigate, :string, required: true
  attr :icon, :string, default: nil
  slot :inner_block, required: true

  def nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-300 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
    >
      <.icon :if={@icon} name={@icon} class="w-4 h-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  User avatar component (imported from TokenComponents).
  """
  defdelegate user_avatar(assigns), to: DdbmWeb.TokenComponents

  @doc """
  Shows the flash group wfith standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

end
