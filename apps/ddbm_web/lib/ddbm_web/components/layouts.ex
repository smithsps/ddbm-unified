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
      <header class="sticky top-0 z-50 bg-base-100/95 backdrop-blur-sm shadow-sm">
        <nav class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <%!-- Logo --%>
            <div class="flex items-center gap-6">
              <.link navigate="/" class="flex items-center gap-2 text-base-content hover:text-primary transition-colors">
                <img src={~p"/images/logo.svg"} width="32" class="brightness-0 invert" />
                <span class="text-xl font-bold">DDBM</span>
              </.link>

              <%!-- Navigation Links (Desktop) --%>
              <div class="hidden md:flex items-center gap-1">
                <.nav_link navigate="/dashboard" icon="hero-home">Dashboard</.nav_link>
                <.nav_link navigate="/tokens/leaderboard" icon="hero-trophy">Leaderboard</.nav_link>
                <.nav_link navigate="/tokens/log" icon="hero-list-bullet">Log</.nav_link>
                <.nav_link navigate="/tokens/give" icon="hero-gift">Give</.nav_link>
                <.nav_link navigate="/admin" icon="hero-chart-bar">Admin</.nav_link>
              </div>
            </div>

            <%!-- Right Side --%>
            <div class="flex items-center gap-4">
              <%!-- User Menu --%>
              <div class="relative group">
                <button class="flex items-center gap-2 px-3 py-2 rounded-lg bg-base-100 hover:bg-base-200 transition-colors">
                  <.user_avatar user={@current_user} size="sm" />
                  <span class="hidden sm:block text-sm font-medium text-base-content">
                    {@current_user.discord_username}
                  </span>
                  <.icon name="hero-chevron-down" class="w-4 h-4 text-base-content/60" />
                </button>

                <%!-- Dropdown Menu --%>
                <div class="absolute right-0 mt-2 w-56 rounded-lg bg-base-100 shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all">
                  <div class="p-3">
                    <div class="mb-3">
                      <.theme_toggle />
                    </div>
                    <div class="h-px bg-base-300 my-2"></div>
                    <.link
                      href="/logout"
                      method="delete"
                      class="flex items-center gap-2 px-4 py-2 text-sm text-base-content/80 hover:bg-base-300 rounded-lg transition-colors"
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
          <div class="md:hidden pt-3 pb-3">
            <div class="flex flex-col gap-1">
              <.nav_link navigate="/dashboard" icon="hero-home">Dashboard</.nav_link>
              <.nav_link navigate="/tokens/leaderboard" icon="hero-trophy">Leaderboard</.nav_link>
              <.nav_link navigate="/tokens/log" icon="hero-list-bullet">Log</.nav_link>
              <.nav_link navigate="/tokens/give" icon="hero-gift">Give</.nav_link>
              <.nav_link navigate="/admin" icon="hero-chart-bar">Admin</.nav_link>
            </div>
          </div>
        </nav>
      </header>
    <% end %>

    <main class="min-h-screen bg-base-200">
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
      class="flex items-center gap-2 px-3 py-2 text-sm font-medium text-base-content/80 hover:text-base-content hover:bg-base-300/50 rounded-lg transition-colors"
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
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  attr :live, :boolean, default: true

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center">
      <div class="absolute w-1/3 h-full rounded-full bg-base-300 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

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
