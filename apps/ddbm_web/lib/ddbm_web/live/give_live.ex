defmodule DdbmWeb.GiveLive do
  use DdbmWeb, :live_view

  alias Ddbm.{Discord, Tokens}
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
    guild_id = Application.get_env(:ddbm_discord, :guild_id)

    search_results =
      if String.length(query) >= 2 and guild_id do
        Discord.search_members(query, guild_id)
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
  def handle_event("select_user", %{"member_id" => member_id}, socket) do
    guild_id = Application.get_env(:ddbm_discord, :guild_id)
    member = Discord.get_member(member_id, guild_id) |> Discord.add_avatar_url()

    socket =
      socket
      |> assign(:selected_user, member)
      |> assign(:search_query, member.display_name || member.username)
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
          member_name = selected_user.display_name || selected_user.username

          socket =
            socket
            |> put_flash(
              :info,
              "Successfully gave 1 #{token_def.name} to #{member_name}!"
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
      <div class="max-w-3xl mx-auto px-4 py-6">
        <h1 class="text-2xl font-bold mb-6">Give Tokens</h1>

        <div class="space-y-2">
          <%!-- Token Selection --%>
          <div class="card bg-base-200">
            <div class="card-body p-4">
              <h2 class="card-title text-base mb-2">Select Token Type</h2>
              <div class="flex gap-2">
                <button
                  :for={token <- @all_tokens}
                  type="button"
                  phx-click="select_token"
                  phx-value-token={token.id}
                  class={[
                    "btn btn-sm h-auto flex-col gap-1 py-2 bg-base-100 flex-shrink-0",
                    @selected_token == token.id && "ring-2 ring-primary"
                  ]}
                >
                  <span class="text-xl">{token.icon}</span>
                  <span class="text-xs">{token.name}</span>
                </button>
              </div>
            </div>
          </div>

          <%!-- Rate Limit Display --%>
          <%= if @rate_limits do %>
            <div class="card bg-base-200">
              <div class="card-body p-4">
                <h2 class="card-title text-base mb-2">Rate Limits</h2>
                <div class="space-y-3">
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
            </div>
          <% end %>

          <%!-- User Search --%>
          <div class="card bg-base-200">
            <div class="card-body p-4">
              <h2 class="card-title text-base mb-2">Select Recipient</h2>
              <div class="relative">
                <form phx-change="search_users">
                  <input
                    type="text"
                    name="query"
                    phx-debounce="300"
                    value={@search_query}
                    placeholder="Search by username..."
                    class="input input-bordered w-full"
                    autocomplete="off"
                  />
                </form>

                <%!-- Search Results Dropdown --%>
                <%= if @showing_results && @search_results != [] do %>
                  <div class="absolute z-10 w-full mt-1 menu bg-base-100 rounded-box shadow-lg max-h-60 overflow-y-auto p-0">
                    <li :for={member <- @search_results}>
                      <button
                        type="button"
                        phx-click="select_user"
                        phx-value-member_id={member.discord_id}
                        class="flex items-center gap-2 p-2"
                      >
                        <div class="avatar">
                          <div class="w-8 rounded-full">
                            <img src={member.avatar_url} alt={member.display_name || member.username} />
                          </div>
                        </div>
                        <div class="flex-1 text-left">
                          <div class="font-medium">{member.display_name || member.username}</div>
                          <div class="text-xs opacity-60">@{member.username}</div>
                        </div>
                      </button>
                    </li>
                  </div>
                <% end %>

                <%!-- No Results Message --%>
                <%= if @showing_results && @search_results == [] && String.length(@search_query) >= 2 do %>
                  <div class="absolute z-10 w-full mt-1 bg-base-100 rounded-box shadow-lg p-3 text-center text-sm opacity-60">
                    No users found matching "{@search_query}"
                  </div>
                <% end %>
              </div>

              <%!-- Selected User Display --%>
              <%= if @selected_user do %>
                <div class="alert mt-3 p-3">
                  <div class="flex items-center gap-2 flex-1">
                    <div class="avatar placeholder">
                      <div class="bg-neutral rounded-full w-8">
                        <img
                          src={@selected_user.avatar_url}
                          alt={@selected_user.display_name}
                          class="w-8 h-8 rounded-full ring-2 ring-primary/30"
                        />
                      </div>
                    </div>
                    <div>
                      <div class="font-medium">{@selected_user.display_name || @selected_user.username}</div>
                      <div class="text-xs opacity-60">Ready to receive</div>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="clear_user"
                    class="btn btn-ghost btn-sm btn-circle"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Give Button --%>
          <button
            type="button"
            phx-click="give_token"
            disabled={!@selected_user || !@rate_limits.can_give}
            class={[
              "btn w-full",
              @selected_user && @rate_limits.can_give && "btn-primary",
              (!@selected_user || !@rate_limits.can_give) && "btn-disabled"
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
