defmodule DdbmWeb.LeaderboardLive do
  use DdbmWeb, :live_view

  alias Ddbm.Tokens
  alias Ddbm.Tokens.Token
  import DdbmWeb.TokenComponents

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if current_user do
      # Get user's token balances
      balances = Tokens.get_user_balances(current_user.discord_id)

      # Get all tokens
      all_tokens = Token.all()

      # Set default selected token
      selected_token = List.first(all_tokens).id

      # Get leaderboard for selected token
      leaderboard = Tokens.get_token_leaderboard(selected_token)

      # Find user's rank
      user_rank = find_user_rank(leaderboard, current_user.discord_id)

      socket =
        socket
        |> assign(:page_title, "Leaderboard")
        |> assign(:balances, balances)
        |> assign(:all_tokens, all_tokens)
        |> assign(:selected_token, selected_token)
        |> assign(:leaderboard, leaderboard)
        |> assign(:user_rank, user_rank)

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event("select_token", %{"token" => token_id}, socket) do
    leaderboard = Tokens.get_token_leaderboard(token_id)
    user_rank = find_user_rank(leaderboard, socket.assigns.current_user.discord_id)

    socket =
      socket
      |> assign(:selected_token, token_id)
      |> assign(:leaderboard, leaderboard)
      |> assign(:user_rank, user_rank)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 class="text-3xl font-bold text-base-content mb-8">Leaderboard</h1>

        <%!-- Token Balance Overview --%>
        <div class="mb-8">
          <h2 class="text-xl font-semibold text-base-content mb-4">Your Balances</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <.token_balance_card
              :for={token <- @all_tokens}
              token={token.id}
              balance={Map.get(@balances, token.id, 0)}
            />
          </div>
        </div>

        <%!-- Leaderboard Section --%>
        <div>
          <h2 class="text-xl font-semibold text-base-content mb-4">Leaderboards</h2>

          <%!-- Token Tabs --%>
          <div class="mb-6 flex gap-2 flex-wrap">
            <button
              :for={token <- @all_tokens}
              phx-click="select_token"
              phx-value-token={token.id}
              class={[
                "px-4 py-2 rounded-lg font-medium transition-all shadow-sm",
                @selected_token == token.id &&
                  "bg-primary text-primary-content shadow-lg shadow-primary/50",
                @selected_token != token.id &&
                  "bg-base-100 text-base-content/80 hover:bg-base-300/50"
              ]}
            >
              {token.name}
            </button>
          </div>

          <%!-- User's Rank Card --%>
          <%= if @user_rank do %>
            <div class="mb-6 p-4 rounded-lg bg-primary/20 shadow-sm">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <.user_avatar user={@current_user} size="sm" />
                  <div>
                    <p class="text-sm text-base-content/60">Your Rank</p>
                    <p class="font-bold text-primary">#{@user_rank.rank}</p>
                  </div>
                </div>
                <div class="text-right">
                  <p class="text-sm text-base-content/60">Your Total</p>
                  <p class="text-2xl font-bold text-primary">{@user_rank.total}</p>
                </div>
              </div>
            </div>
          <% else %>
            <div class="mb-6 p-4 rounded-lg bg-base-100 shadow-sm">
              <p class="text-center text-base-content/60">
                You haven't received any {Token.get(@selected_token).plural} yet.
              </p>
            </div>
          <% end %>

          <%!-- Leaderboard Table --%>
          <%= if @leaderboard == [] do %>
            <div class="p-12 text-center rounded-lg bg-base-100 shadow-sm">
              <div class="text-6xl mb-4">🏆</div>
              <p class="text-base-content/60">No leaderboard data yet</p>
            </div>
          <% else %>
            <.leaderboard_table
              token={@selected_token}
              entries={@leaderboard}
              current_user_id={@current_user.discord_id}
            />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp find_user_rank(leaderboard, user_id) do
    leaderboard
    |> Enum.with_index(1)
    |> Enum.find(fn {entry, _index} -> entry.user_id == user_id end)
    |> case do
      {entry, rank} -> %{rank: rank, total: entry.total}
      nil -> nil
    end
  end
end
