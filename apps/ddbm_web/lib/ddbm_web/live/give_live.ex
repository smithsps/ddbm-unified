defmodule DdbmWeb.GiveLive do
  use DdbmWeb, :live_view

  alias Ddbm.{Accounts, Tokens}
  alias Ddbm.Tokens.Token
  import DdbmWeb.TokenComponents

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if current_user do
      all_tokens = Token.all()
      selected_token = List.first(all_tokens).id

      socket =
        socket
        |> assign(:page_title, "Give Tokens")
        |> assign(:all_tokens, all_tokens)
        |> assign(:selected_token, selected_token)
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> assign(:selected_user, nil)
        |> assign(:showing_results, false)
        |> load_rate_limits()

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event("select_token", %{"token" => token_id}, socket) do
    socket =
      socket
      |> assign(:selected_token, token_id)
      |> load_rate_limits()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_users", %{"query" => query}, socket) do
    search_results =
      if String.length(query) >= 2 do
        Accounts.search_users_by_username(query)
        |> Enum.reject(&(&1.discord_id == socket.assigns.current_user.discord_id))
      else
        []
      end

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:search_results, search_results)
      |> assign(:showing_results, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user(String.to_integer(user_id))

    socket =
      socket
      |> assign(:selected_user, user)
      |> assign(:search_query, user.discord_username)
      |> assign(:showing_results, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_user", _params, socket) do
    socket =
      socket
      |> assign(:selected_user, nil)
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:showing_results, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("give_token", _params, socket) do
    current_user = socket.assigns.current_user
    selected_user = socket.assigns.selected_user
    selected_token = socket.assigns.selected_token

    if selected_user do
      case Tokens.give_token(
             current_user.discord_id,
             selected_user.discord_id,
             selected_token,
             1
           ) do
        {:ok, _transaction} ->
          token_def = Token.get(selected_token)

          socket =
            socket
            |> put_flash(
              :info,
              "Successfully gave 1 #{token_def.name} to #{selected_user.discord_username}!"
            )
            |> assign(:selected_user, nil)
            |> assign(:search_query, "")
            |> assign(:search_results, [])
            |> load_rate_limits()

          {:noreply, socket}

        {:error, :cannot_give_to_self} ->
          {:noreply, put_flash(socket, :error, "You cannot give tokens to yourself.")}

        {:error, {:daily_limit, _current, limit}} ->
          token_def = Token.get(selected_token)

          {:noreply,
           put_flash(
             socket,
             :error,
             "Daily limit reached! You can only give #{limit} #{token_def.plural} per day."
           )}

        {:error, {:weekly_limit, _current, limit}} ->
          token_def = Token.get(selected_token)

          {:noreply,
           put_flash(
             socket,
             :error,
             "Weekly limit reached! You can only give #{limit} #{token_def.plural} per week."
           )}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to give token. Please try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select a user first.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 class="text-3xl font-bold text-base-content mb-8">Give Tokens</h1>

        <div class="space-y-6">
          <%!-- Token Selection --%>
          <div>
            <label class="block text-sm font-medium text-base-content/80 mb-3">
              Select Token Type
            </label>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <button
                :for={token <- @all_tokens}
                type="button"
                phx-click="select_token"
                phx-value-token={token.id}
                class={[
                  "p-4 rounded-lg text-left transition-all",
                  @selected_token == token.id &&
                    "bg-primary border-2 border-primary shadow-lg shadow-primary/50",
                  @selected_token != token.id &&
                    "bg-base-200/50 border-2 border-base-300 hover:bg-base-200"
                ]}
              >
                <div class="flex items-center justify-between mb-2">
                  <span class="text-2xl">{String.first(token.name)}</span>
                  <%= if @selected_token == token.id do %>
                    <span class="text-success">✓</span>
                  <% end %>
                </div>
                <div class="font-medium text-base-content">{token.name}</div>
              </button>
            </div>
          </div>

          <%!-- Rate Limit Display --%>
          <%= if @rate_limits do %>
            <div class="p-6 rounded-lg bg-base-200/50 border border-base-300">
              <h3 class="text-lg font-semibold text-base-content mb-4">Rate Limits</h3>
              <div class="space-y-4">
                <%= if @rate_limits.daily_limit do %>
                  <.rate_limit_indicator
                    token={@selected_token}
                    used={@rate_limits.daily_used}
                    limit={@rate_limits.daily_limit}
                    period="daily"
                  />
                <% end %>
                <%= if @rate_limits.weekly_limit do %>
                  <.rate_limit_indicator
                    token={@selected_token}
                    used={@rate_limits.weekly_used}
                    limit={@rate_limits.weekly_limit}
                    period="weekly"
                  />
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- User Search --%>
          <div>
            <label class="block text-sm font-medium text-base-content/80 mb-3">
              Search for User
            </label>
            <div class="relative">
              <input
                type="text"
                phx-keyup="search_users"
                phx-debounce="300"
                value={@search_query}
                placeholder="Type username to search..."
                class="w-full px-4 py-3 rounded-lg bg-base-200/50 border border-base-300 text-base-content placeholder-base-content/50 focus:outline-none focus:ring-2 focus:ring-primary"
              />

              <%!-- Search Results Dropdown --%>
              <%= if @showing_results && @search_results != [] do %>
                <div class="absolute z-10 w-full mt-2 rounded-lg bg-base-200 border border-base-300 shadow-xl max-h-64 overflow-y-auto">
                  <button
                    :for={user <- @search_results}
                    type="button"
                    phx-click="select_user"
                    phx-value-user_id={user.id}
                    class="w-full px-4 py-3 flex items-center gap-3 hover:bg-base-300 transition-colors text-left"
                  >
                    <.user_avatar user={user} size="sm" />
                    <div>
                      <div class="font-medium text-base-content">{user.discord_username}</div>
                      <div class="text-sm text-base-content/60">Discord ID: {user.discord_id}</div>
                    </div>
                  </button>
                </div>
              <% end %>

              <%!-- No Results Message --%>
              <%= if @showing_results && @search_results == [] && String.length(@search_query) >= 2 do %>
                <div class="absolute z-10 w-full mt-2 rounded-lg bg-base-200 border border-base-300 shadow-xl p-4 text-center text-base-content/60">
                  No users found matching "{@search_query}"
                </div>
              <% end %>
            </div>

            <%!-- Selected User Display --%>
            <%= if @selected_user do %>
              <div class="mt-4 p-4 rounded-lg bg-primary/20 border border-primary/40 flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <.user_avatar user={@selected_user} size="md" />
                  <div>
                    <div class="font-medium text-base-content">{@selected_user.discord_username}</div>
                    <div class="text-sm text-base-content/60">Ready to receive token</div>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="clear_user"
                  class="text-base-content/60 hover:text-base-content transition-colors"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>
            <% end %>
          </div>

          <%!-- Give Button --%>
          <button
            type="button"
            phx-click="give_token"
            disabled={!@selected_user || !@rate_limits.can_give}
            class={[
              "w-full py-4 rounded-lg font-bold text-lg transition-all",
              @selected_user && @rate_limits.can_give &&
                "bg-gradient-to-r from-primary to-secondary text-primary-content hover:opacity-90 shadow-lg hover:shadow-xl",
              (!@selected_user || !@rate_limits.can_give) &&
                "bg-base-300 text-base-content/50 cursor-not-allowed"
            ]}
          >
            <%= cond do %>
              <% !@selected_user -> %>
                Select a user to give token
              <% !@rate_limits.can_give -> %>
                Rate limit reached
              <% true -> %>
                Give {Token.get(@selected_token).name}
            <% end %>
          </button>

          <%!-- Help Text --%>
          <div class="p-4 rounded-lg bg-info/10 border border-info/20">
            <div class="flex gap-3">
              <div class="text-2xl">💡</div>
              <div class="text-sm text-base-content/80">
                <p class="font-medium mb-1">How it works:</p>
                <ul class="list-disc list-inside space-y-1 text-base-content/60">
                  <li>Select the token type you want to give</li>
                  <li>Search for a user by their Discord username</li>
                  <li>Check that you haven't reached your rate limit</li>
                  <li>Click the give button to send the token</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_rate_limits(socket) do
    current_user = socket.assigns.current_user
    selected_token = socket.assigns.selected_token

    rate_limits = Tokens.get_rate_limit_status(current_user.discord_id, selected_token)

    assign(socket, :rate_limits, rate_limits)
  end
end
