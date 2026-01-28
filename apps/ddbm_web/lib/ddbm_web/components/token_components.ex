defmodule DdbmWeb.TokenComponents do
  @moduledoc """
  Reusable components for token display and interaction.
  """

  use Phoenix.Component

  alias Ddbm.Tokens.Token
  alias Ddbm.Discord

  @doc """
  Displays a token badge with emoji and amount.

  ## Examples

      <.token_badge token="carry" amount={3} />
      <.token_badge token="leader" amount={1} />

  """
  attr :token, :string, required: true
  attr :amount, :integer, required: true
  attr :class, :string, default: ""

  def token_badge(assigns) do
    token_def = Token.get(assigns.token)
    assigns = assign(assigns, :token_name, Token.display_name(token_def, assigns.amount))

    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full",
      "bg-gradient-to-r from-purple-500/10 to-blue-500/10",
      "border border-purple-500/20 text-sm font-medium",
      @class
    ]}>
      <span class="text-lg">{String.first(@token_name)}</span>
      <span>{@amount}</span>
    </span>
    """
  end

  @doc """
  Displays a transaction row.

  ## Examples

      <.transaction_row transaction={@transaction} current_user_id={@current_user.discord_id} />

  """
  attr :transaction, :map, required: true
  attr :current_user_id, :string, default: nil
  attr :class, :string, default: ""
  attr :id, :string, default: nil

  def transaction_row(assigns) do
    token_def = Token.get(assigns.transaction.token)
    guild_id = Application.get_env(:ddbm_discord, :guild_id)

    sender_name = Discord.get_display_name(assigns.transaction.sender_user_id, guild_id)
    receiver_name = Discord.get_display_name(assigns.transaction.user_id, guild_id)

    assigns =
      assigns
      |> assign(:token_name, Token.display_name(token_def, assigns.transaction.amount))
      |> assign(:is_received, assigns.transaction.user_id == assigns.current_user_id)
      |> assign(:sender_name, sender_name)
      |> assign(:receiver_name, receiver_name)

    ~H"""
    <div
      id={@id}
      class={[
        "flex items-center justify-between p-4 rounded-lg",
        "bg-white/5 border border-white/10 hover:bg-white/10 transition-colors",
        @class
      ]}
    >
      <div class="flex items-center gap-4">
        <div class="text-2xl">{String.first(@token_name)}</div>
        <div>
          <div class="font-medium">
            <%= if @is_received do %>
              <span class="text-green-400">+{@transaction.amount}</span> from
              <span class="text-purple-300">{@sender_name}</span>
            <% else %>
              <span class="text-blue-400">-{@transaction.amount}</span> to
              <span class="text-purple-300">{@receiver_name}</span>
            <% end %>
          </div>
          <div class="text-sm text-gray-400">
            {Calendar.strftime(@transaction.inserted_at, "%b %d, %Y at %I:%M %p")}
          </div>
        </div>
      </div>
      <div class="text-xs text-gray-500">{@transaction.source}</div>
    </div>
    """
  end

  @doc """
  Displays a user avatar with Discord profile picture.

  ## Examples

      <.user_avatar user={@user} size="sm" />
      <.user_avatar user={@user} size="lg" />

  """
  attr :user, :map, required: true
  attr :size, :string, default: "md"
  attr :class, :string, default: ""

  def user_avatar(assigns) do
    size_classes =
      case assigns.size do
        "sm" -> "w-8 h-8"
        "md" -> "w-12 h-12"
        "lg" -> "w-16 h-16"
        "xl" -> "w-24 h-24"
        _ -> "w-12 h-12"
      end

    assigns = assign(assigns, :size_classes, size_classes)

    ~H"""
    <%= if @user.discord_avatar do %>
      <img
        src={@user.discord_avatar}}
        alt={@user.discord_username}
        class={[@size_classes, "rounded-full border-2 border-purple-500/50", @class]}
      />
    <% else %>
      <div class={[
        @size_classes,
        "rounded-full border-2 border-purple-500/50 bg-gradient-to-br from-purple-500 to-blue-500",
        "flex items-center justify-center text-white font-bold",
        @class
      ]}>
        {String.first(@user)}
      </div>
    <% end %>
    """
  end

  @doc """
  Displays a token balance card.

  ## Examples

      <.token_balance_card token="carry" balance={5} />

  """
  attr :token, :string, required: true
  attr :balance, :integer, required: true
  attr :class, :string, default: ""

  def token_balance_card(assigns) do
    token_def = Token.get(assigns.token)
    assigns = assign(assigns, :token_def, token_def)

    ~H"""
    <div class={[
      "p-6 rounded-xl bg-gradient-to-br from-purple-500/10 to-blue-500/10",
      "border border-purple-500/20 hover:border-purple-500/40 transition-all",
      "hover:shadow-lg hover:shadow-purple-500/20",
      @class
    ]}>
      <div class="flex items-center justify-between mb-2">
        <span class="text-4xl">{String.first(@token_def.name)}</span>
        <span class="text-3xl font-bold text-purple-300">{@balance}</span>
      </div>
      <div class="text-sm text-gray-300 font-medium">
        {Token.display_name(@token_def, @balance)}
      </div>
    </div>
    """
  end

  @doc """
  Displays a leaderboard table.

  ## Examples

      <.leaderboard_table token="carry" entries={@leaderboard_entries} current_user_id={@current_user.discord_id} />

  """
  attr :token, :string, required: true
  attr :entries, :list, required: true
  attr :current_user_id, :string, default: nil
  attr :class, :string, default: ""

  def leaderboard_table(assigns) do
    token_def = Token.get(assigns.token)
    guild_id = Application.get_env(:ddbm_discord, :guild_id)

    # Use ETS-cached lookups
    entries_with_names =
      Enum.map(assigns.entries, fn entry ->
        display_name = Discord.get_display_name(entry.user_id, guild_id)
        Map.put(entry, :display_name, display_name)
      end)

    assigns =
      assigns
      |> assign(:token_def, token_def)
      |> assign(:entries_with_names, entries_with_names)

    ~H"""
    <div class={["overflow-hidden rounded-lg border border-white/10", @class]}>
      <table class="w-full">
        <thead class="bg-white/5 border-b border-white/10">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
              Rank
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
              User
            </th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider">
              {String.first(@token_def.name)} Total
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-white/10">
          <tr
            :for={{entry, index} <- Enum.with_index(@entries_with_names, 1)}
            class={[
              "hover:bg-white/5 transition-colors",
              entry.user_id == @current_user_id && "bg-purple-500/10"
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
                    <span class="text-sm text-gray-400">#{index}</span>
                <% end %>
              </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <div class="flex items-center gap-3">
                <div class={[
                  "w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-blue-500",
                  "flex items-center justify-center text-white font-bold text-sm"
                ]}>
                  {String.first(entry.display_name)}
                </div>
                <span class={[
                  "font-medium",
                  entry.user_id == @current_user_id && "text-purple-300"
                ]}>
                  {entry.display_name}
                  <%= if entry.user_id == @current_user_id do %>
                    <span class="ml-2 text-xs text-purple-400">(You)</span>
                  <% end %>
                </span>
              </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-right">
              <span class="text-lg font-bold text-purple-300">{entry.total}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Displays a rate limit indicator.

  ## Examples

      <.rate_limit_indicator token="carry" used={2} limit={3} />

  """
  attr :token, :string, required: true
  attr :used, :integer, required: true
  attr :limit, :integer, required: true
  attr :period, :string, default: "daily"
  attr :class, :string, default: ""

  def rate_limit_indicator(assigns) do
    token_def = Token.get(assigns.token)
    percentage = if assigns.limit > 0, do: assigns.used / assigns.limit * 100, else: 0
    remaining = max(assigns.limit - assigns.used, 0)

    assigns =
      assigns
      |> assign(:token_def, token_def)
      |> assign(:percentage, percentage)
      |> assign(:remaining, remaining)

    ~H"""
    <div class={["space-y-2", @class]}>
      <div class="flex items-center justify-between text-sm">
        <span class="text-gray-400">
          {String.first(@token_def.name)} {@period} limit
        </span>
        <span class={[
          "font-medium",
          @remaining > 0 && "text-green-400",
          @remaining == 0 && "text-red-400"
        ]}>
          {@used}/{@limit}
        </span>
      </div>
      <div class="h-2 bg-white/10 rounded-full overflow-hidden">
        <div
          class={[
            "h-full transition-all duration-300",
            @percentage < 75 && "bg-green-500",
            @percentage >= 75 && @percentage < 100 && "bg-yellow-500",
            @percentage >= 100 && "bg-red-500"
          ]}
          style={"width: #{min(@percentage, 100)}%"}
        >
        </div>
      </div>
      <%= if @remaining > 0 do %>
        <p class="text-xs text-gray-500">{@remaining} remaining {@period}</p>
      <% else %>
        <p class="text-xs text-red-400">Limit reached for {@period}</p>
      <% end %>
    </div>
    """
  end
end
