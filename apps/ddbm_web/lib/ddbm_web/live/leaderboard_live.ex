defmodule DdbmWeb.LeaderboardLive do
  use DdbmWeb, :live_view

  alias Ddbm.Discord
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
          <div class="mb-6 flex flex-wrap join">
            <button
              :for={token <- @all_tokens}
              phx-click="select_token"
              phx-value-token={token.id}
              class={[
                "px-4 py-2 font-medium transition-all join-item",
                @selected_token == token.id &&
                  "bg-primary text-primary-content",
                @selected_token != token.id &&
                  "bg-base-100 text-base-content hover:bg-base-300"
              ]}
            >
              {token.icon}
            </button>
          </div>

          <%!-- Leaderboard Table --%>
          <%= if @leaderboard == [] do %>
            <div class="p-12 text-center rounded-lg bg-base-100 shadow-sm">
              <div class="text-6xl mb-4">🏆</div>
              <p class="text-base-content/60">No leaderboard data yet</p>
            </div>
          <% else %>
            <%
              token_def = Token.get(@selected_token)
              guild_id = Application.get_env(:ddbm_discord, :guild_id)

              entries_with_names =
                Enum.map(@leaderboard, fn entry ->
                  display_name = Discord.get_display_name(entry.user_id, guild_id)
                  avatar_url = Discord.get_avatar(entry.user_id, guild_id)

                  entry
                  |> Map.put(:display_name, display_name)
                  |> Map.put(:avatar_url, avatar_url)
                end)
            %>
            <div class="overflow-hidden rounded-lg bg-base-100 shadow-sm">
              <table class="w-full">
                <thead class="bg-base-300/30">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-base-content/60 uppercase tracking-wider">
                      Rank
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-base-content/60 uppercase tracking-wider">
                      User
                    </th>
                    <th class="px-6 py-3 text-right text-xs font-medium text-base-content/60 uppercase tracking-wider">
                      {token_def.icon} Total
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-base-300/30">
                  <tr
                    :for={{entry, index} <- Enum.with_index(entries_with_names, 1)}
                    class={[
                      "hover:bg-base-200 transition-colors",
                      entry.user_id == @current_user.discord_id && "bg-base-200"
                    ]}
                  >
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center gap-2">
                        <%= cond do %>
                          <% index == 1 -> %>
                            <span class="text-2xl">🥇</span>
                          <% index == 2 -> %>
                            <span class="text-2xl">🥈</span>
                          <% index == 3 -> %>
                            <span class="text-2xl">🥉</span>
                          <% true -> %>
                            <span class="text-sm text-base-content/60">#{index}</span>
                        <% end %>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center gap-3">
                        <%= if entry.avatar_url do %>
                          <img
                            src={entry.avatar_url}
                            alt={entry.display_name}
                            class="w-8 h-8 rounded-full ring-2 ring-primary/30"
                          />
                        <% else %>
                          <div class={[
                            "w-8 h-8 rounded-full bg-primary",
                            "flex items-center justify-center text-primary-content font-bold text-sm"
                          ]}>
                            {String.first(entry.display_name)}
                          </div>
                        <% end %>
                        <span class={[
                          "font-medium",
                          entry.user_id == @current_user.discord_id && "text-primary"
                        ]}>
                          {entry.display_name}
                          <%= if entry.user_id == @current_user.discord_id do %>
                            <span class="ml-2 text-xs text-primary/80">(You)</span>
                          <% end %>
                        </span>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right">
                      <span class="text-lg font-bold text-base-content">{entry.total}</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
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
