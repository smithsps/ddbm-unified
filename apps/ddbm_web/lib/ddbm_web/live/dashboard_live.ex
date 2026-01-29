defmodule DdbmWeb.DashboardLive do
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

      # Get recent transactions
      recent_transactions =
        current_user.discord_id
        |> Tokens.get_transactions_by_user()
        |> Enum.take(10)

      # Calculate stats
      total_received =
        Tokens.get_transactions_by_user(current_user.discord_id)
        |> Enum.reduce(0, &(&1.amount + &2))

      total_given =
        Tokens.get_transactions_sent_by_user(
          current_user.discord_id,
          nil,
          DateTime.add(DateTime.utc_now(), -365, :day)
        )
        |> Enum.reduce(0, &(&1.amount + &2))

      socket =
        socket
        |> assign(:page_title, "Dashboard")
        |> assign(:balances, balances)
        |> assign(:recent_transactions, recent_transactions)
        |> assign(:total_received, total_received)
        |> assign(:total_given, total_given)
        |> assign(:all_tokens, Token.all())

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- User Profile Card --%>
        <div class="mb-8 p-6 rounded-xl bg-base-100 shadow-sm">
          <div class="flex items-center gap-4">
            <.user_avatar user={@current_user} size="xl" />
            <div>
              <h1 class="text-3xl font-bold text-base-content mb-1">
                Welcome, {@current_user.discord_username}!
              </h1>
              <p class="text-base-content/60">
                Last login: {format_datetime(@current_user.last_login_at)}
              </p>
            </div>
          </div>
        </div>

        <%!-- Token Balance Cards --%>
        <div class="mb-8">
          <h2 class="text-xl font-bold text-base-content mb-4">Your Token Balances</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <.token_balance_card
              :for={token <- @all_tokens}
              token={token.id}
              balance={Map.get(@balances, token.id, 0)}
            />
          </div>
        </div>

        <%!-- Recent Transactions --%>
        <div>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-2xl font-bold text-base-content">Recent Activity</h2>
            <.link
              navigate={~p"/transactions"}
              class="text-sm text-primary hover:text-primary/80"
            >
              View all →
            </.link>
          </div>

          <%= if @recent_transactions == [] do %>
            <div class="p-12 text-center rounded-lg bg-base-100 shadow-sm">
              <div class="text-6xl mb-4">🎁</div>
              <p class="text-base-content/60 mb-2">No transactions yet</p>
              <p class="text-sm text-base-content/50">
                Start giving or receiving tokens to see activity here!
              </p>
            </div>
          <% else %>
            <div class="space-y-3">
              <.transaction_row
                :for={transaction <- @recent_transactions}
                transaction={transaction}
                current_user_id={@current_user.discord_id}
              />
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end
end
