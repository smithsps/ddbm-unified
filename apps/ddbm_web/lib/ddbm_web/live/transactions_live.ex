defmodule DdbmWeb.TransactionsLive do
  use DdbmWeb, :live_view

  alias Ddbm.Tokens
  alias Ddbm.Tokens.Token
  import DdbmWeb.TokenComponents

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if current_user do
      socket =
        socket
        |> assign(:page_title, "Transaction History")
        |> assign(:page, 1)
        |> assign(:per_page, 20)
        |> assign(:filter_token, nil)
        |> assign(:all_tokens, Token.all())
        |> stream_configure(:transactions, dom_id: &"transaction-#{&1.id}")
        |> load_transactions()

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event("filter_token", %{"token" => ""}, socket) do
    socket =
      socket
      |> assign(:filter_token, nil)
      |> assign(:page, 1)
      |> load_transactions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_token", %{"token" => token_id}, socket) do
    socket =
      socket
      |> assign(:filter_token, token_id)
      |> assign(:page, 1)
      |> load_transactions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    page = socket.assigns.page
    total_pages = socket.assigns.total_pages

    if page < total_pages do
      socket =
        socket
        |> assign(:page, page + 1)
        |> load_transactions()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    page = socket.assigns.page

    if page > 1 do
      socket =
        socket
        |> assign(:page, page - 1)
        |> load_transactions()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 class="text-3xl font-bold text-base-content mb-8">Transaction History</h1>

        <%!-- Filters --%>
        <div class="mb-6 flex gap-4 items-center">
          <label class="text-sm text-base-content/60">Filter by token:</label>
          <select
            phx-change="filter_token"
            name="token"
            class="px-4 py-2 rounded-lg bg-base-100 shadow-sm text-base-content"
          >
            <option value="">All tokens</option>
            <option :for={token <- @all_tokens} value={token.id} selected={@filter_token == token.id}>
              {token.name}
            </option>
          </select>
        </div>

        <%!-- Transactions List --%>
        <%= if @total_count == 0 do %>
          <div class="p-12 text-center rounded-lg bg-base-100 shadow-sm">
            <div class="text-6xl mb-4">📜</div>
            <p class="text-base-content/60 mb-2">No transactions found</p>
            <p class="text-sm text-base-content/50">
              <%= if @filter_token do %>
                Try changing your filter or <.link
                  phx-click="filter_token"
                  phx-value-token=""
                  class="text-primary hover:text-primary/80"
                >view all transactions</.link>.
              <% else %>
                Start giving or receiving tokens to see your history here!
              <% end %>
            </p>
          </div>
        <% else %>
          <div id="transactions" phx-update="stream" class="space-y-3 mb-6">
            <.transaction_row
              :for={{id, transaction} <- @streams.transactions}
              id={id}
              transaction={transaction}
              current_user_id={@current_user.discord_id}
            />
          </div>

          <%!-- Pagination --%>
          <div class="flex items-center justify-between">
            <div class="text-sm text-base-content/60">
              Showing {@per_page * (@page - 1) + 1} to {min(@per_page * @page, @total_count)} of {@total_count} transactions
            </div>
            <div class="flex gap-2">
              <button
                phx-click="prev_page"
                disabled={@page == 1}
                class={[
                  "px-4 py-2 rounded-lg font-medium transition-all shadow-sm",
                  @page == 1 &&
                    "bg-base-100 text-base-content/50 cursor-not-allowed",
                  @page > 1 &&
                    "bg-primary text-primary-content hover:bg-primary/90"
                ]}
              >
                ← Previous
              </button>
              <div class="px-4 py-2 bg-base-100 rounded-lg text-base-content shadow-sm">
                Page {@page} of {@total_pages}
              </div>
              <button
                phx-click="next_page"
                disabled={@page == @total_pages}
                class={[
                  "px-4 py-2 rounded-lg font-medium transition-all shadow-sm",
                  @page == @total_pages &&
                    "bg-base-100 text-base-content/50 cursor-not-allowed",
                  @page < @total_pages &&
                    "bg-primary text-primary-content hover:bg-primary/90"
                ]}
              >
                Next →
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_transactions(socket) do
    current_user = socket.assigns.current_user
    page = socket.assigns.page
    per_page = socket.assigns.per_page
    filter_token = socket.assigns.filter_token

    opts = [
      page: page,
      per_page: per_page,
      direction: :all
    ]

    opts =
      if filter_token do
        Keyword.put(opts, :token, filter_token)
      else
        opts
      end

    result = Tokens.get_transactions_by_user(current_user.discord_id, opts)

    socket
    |> assign(:total_count, result.total_count)
    |> assign(:total_pages, result.total_pages)
    |> stream(:transactions, result.entries, reset: true)
  end
end
