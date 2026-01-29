defmodule Ddbm.Tokens do
  @moduledoc """
  Context for token transactions between Discord users.
  """

  import Ecto.Query, warn: false
  alias Ddbm.Repo
  alias Ddbm.Tokens.{Token, Transaction}

  @doc """
  Creates a new transaction.
  """
  def create_transaction(attrs \\ %{}) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all transactions where the user received tokens.
  """
  def get_transactions_by_user(user_id) do
    Transaction
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets transactions for a user with pagination and optional filters.

  Options:
    - :page - Page number (default: 1)
    - :per_page - Items per page (default: 20)
    - :token - Filter by token type (optional)
    - :direction - :received (default) or :all

  Returns a map with :entries and :total_count.
  """
  def get_transactions_by_user(user_id, opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    token_filter = Keyword.get(opts, :token)
    direction = Keyword.get(opts, :direction, :received)

    query =
      case direction do
        :all ->
          from(t in Transaction,
            where: t.user_id == ^user_id or t.sender_user_id == ^user_id
          )

        :received ->
          from(t in Transaction, where: t.user_id == ^user_id)
      end

    query =
      if token_filter do
        where(query, [t], t.token == ^token_filter)
      else
        query
      end

    total_count = Repo.aggregate(query, :count)

    entries =
      query
      |> order_by([t], desc: t.inserted_at)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      entries: entries,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: ceil(total_count / per_page)
    }
  end

  @doc """
  Gets all transactions with pagination and optional filters.

  Options:
    - :page - Page number (default: 1)
    - :per_page - Items per page (default: 20)
    - :token - Filter by token type (optional)

  Returns a map with :entries, :total_count, :page, :per_page, and :total_pages.
  """
  def get_all_transactions(opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    token_filter = Keyword.get(opts, :token)

    query = from(t in Transaction)

    query =
      if token_filter do
        where(query, [t], t.token == ^token_filter)
      else
        query
      end

    total_count = Repo.aggregate(query, :count)

    entries =
      query
      |> order_by([t], desc: t.inserted_at)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      entries: entries,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: ceil(total_count / per_page)
    }
  end

  @doc """
  Gets transactions sent by a user for a specific token type since a given datetime.
  Used for rate limit checking.
  """
  def get_transactions_sent_by_user(sender_user_id, token, since) do
    query =
      Transaction
      |> where([t], t.sender_user_id == ^sender_user_id)
      |> where([t], t.inserted_at >= ^since)

    query =
      if token do
        where(query, [t], t.token == ^token)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets aggregated token totals for leaderboard display.
  Returns a list of {user_id, total} tuples ordered by total descending.
  """
  def get_token_totals(token) do
    Transaction
    |> where([t], t.token == ^token)
    |> group_by([t], t.user_id)
    |> select([t], {t.user_id, sum(t.amount)})
    |> order_by([t], desc: sum(t.amount))
    |> Repo.all()
  end

  @doc """
  Gets token balances for a user across all token types.
  Returns a map of %{token_id => total_amount}.
  """
  def get_user_balances(user_id) do
    Transaction
    |> where([t], t.user_id == ^user_id)
    |> group_by([t], t.token)
    |> select([t], {t.token, sum(t.amount)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Checks if a user can give a token based on rate limits.

  Returns:
    - {:ok, :allowed} if the user can give the token
    - {:error, :daily_limit, current, limit} if daily limit exceeded
    - {:error, :weekly_limit, current, limit} if weekly limit exceeded
  """
  def check_rate_limit(sender_user_id, token_id) do
    token = Token.get(token_id)

    if token do
      do_check_rate_limit(sender_user_id, token)
    else
      {:error, :invalid_token}
    end
  end

  defp do_check_rate_limit(sender_user_id, token) do
    now = DateTime.utc_now()
    beginning_of_day = beginning_of_day(now)
    beginning_of_week = beginning_of_week(now)

    # Get all transactions since beginning of week (covers both daily and weekly)
    transactions = get_transactions_sent_by_user(sender_user_id, token.id, beginning_of_week)

    # Check daily limit
    daily_total =
      transactions
      |> Enum.filter(&(DateTime.compare(&1.inserted_at, beginning_of_day) != :lt))
      |> Enum.reduce(0, &(&1.amount + &2))

    daily_limit = token.limits[:daily]

    if daily_limit && daily_total >= daily_limit do
      {:error, :daily_limit, daily_total, daily_limit}
    else
      # Check weekly limit
      weekly_total = Enum.reduce(transactions, 0, &(&1.amount + &2))
      weekly_limit = token.limits[:weekly]

      if weekly_limit && weekly_total >= weekly_limit do
        {:error, :weekly_limit, weekly_total, weekly_limit}
      else
        {:ok, :allowed}
      end
    end
  end

  @doc """
  Returns the beginning of today at 3 AM PST (10 AM UTC, or 11 AM UTC during DST).
  If current time is before 3 AM PST, returns yesterday's 3 AM PST.

  Note: This matches the original bot's behavior where the "day" resets at 3 AM PST.
  """
  def beginning_of_day(now \\ DateTime.utc_now()) do
    # 3 AM PST = 11 AM UTC (or 10 AM UTC during PDT)
    # Using 11 AM UTC as the cutoff (PST, not PDT)
    reset_hour = 11

    today_reset =
      now
      |> DateTime.to_date()
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")
      |> DateTime.add(reset_hour * 3600, :second)

    if DateTime.compare(now, today_reset) == :lt do
      # Before today's reset, use yesterday's reset
      DateTime.add(today_reset, -24 * 3600, :second)
    else
      today_reset
    end
  end

  @doc """
  Returns the beginning of the current week (Monday) at 3 AM PST.
  """
  def beginning_of_week(now \\ DateTime.utc_now()) do
    # Get the current day of week (1 = Monday, 7 = Sunday)
    day_of_week = Date.day_of_week(DateTime.to_date(now))

    # Calculate days since Monday
    days_since_monday = day_of_week - 1

    # Get this week's Monday at reset time
    monday_reset =
      now
      |> DateTime.to_date()
      |> Date.add(-days_since_monday)
      |> DateTime.new!(~T[11:00:00], "Etc/UTC")

    # If we're before this week's Monday reset, go back another week
    if DateTime.compare(now, monday_reset) == :lt do
      DateTime.add(monday_reset, -7 * 24 * 3600, :second)
    else
      monday_reset
    end
  end

  @doc """
  Gets the leaderboard for a specific token type with user information.

  Returns a list of maps with user_id, total, and user data (if available).
  Limited to top 100 users.
  """
  def get_token_leaderboard(token, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    query =
      from(t in Transaction,
        where: t.token == ^token,
        group_by: t.user_id,
        select: %{
          user_id: t.user_id,
          total: sum(t.amount)
        },
        order_by: [desc: sum(t.amount)],
        limit: ^limit
      )

    Repo.all(query)
  end

  @doc """
  Checks if a user can give a token (wrapper around check_rate_limit).

  Returns true if allowed, false otherwise.
  """
  def can_give_token?(sender_user_id, token_id, _amount \\ 1) do
    case check_rate_limit(sender_user_id, token_id) do
      {:ok, :allowed} -> true
      _ -> false
    end
  end

  @doc """
  Gives a token from one user to another via the web interface.

  Creates a transaction with source "WebGiveToken".
  Checks rate limits before creating the transaction.

  Returns:
    - {:ok, transaction} if successful
    - {:error, reason} if rate limit exceeded or invalid
  """
  def give_token(sender_user_id, receiver_user_id, token_id, amount \\ 1) do
    # Prevent self-gifting
    if sender_user_id == receiver_user_id do
      {:error, :cannot_give_to_self}
    else
      # Check rate limits
      case check_rate_limit(sender_user_id, token_id) do
        {:ok, :allowed} ->
          create_transaction(%{
            user_id: receiver_user_id,
            sender_user_id: sender_user_id,
            token: token_id,
            amount: amount,
            source: "WebGiveToken"
          })

        {:error, :daily_limit, current, limit} ->
          {:error, {:daily_limit, current, limit}}

        {:error, :weekly_limit, current, limit} ->
          {:error, {:weekly_limit, current, limit}}

        error ->
          error
      end
    end
  end

  @doc """
  Gets the current rate limit status for a user and token.

  Returns a map with:
    - :daily_used - number of tokens given today
    - :daily_limit - daily limit for this token
    - :weekly_used - number of tokens given this week
    - :weekly_limit - weekly limit for this token
    - :can_give - boolean indicating if user can give more
  """
  def get_rate_limit_status(sender_user_id, token_id) do
    token = Token.get(token_id)

    if token do
      now = DateTime.utc_now()
      beginning_of_day = beginning_of_day(now)
      beginning_of_week = beginning_of_week(now)

      transactions = get_transactions_sent_by_user(sender_user_id, token.id, beginning_of_week)

      daily_used =
        transactions
        |> Enum.filter(&(DateTime.compare(&1.inserted_at, beginning_of_day) != :lt))
        |> Enum.reduce(0, &(&1.amount + &2))

      weekly_used = Enum.reduce(transactions, 0, &(&1.amount + &2))

      daily_limit = token.limits[:daily]
      weekly_limit = token.limits[:weekly]

      can_give =
        (is_nil(daily_limit) || daily_used < daily_limit) &&
          (is_nil(weekly_limit) || weekly_used < weekly_limit)

      %{
        daily_used: daily_used,
        daily_limit: daily_limit,
        weekly_used: weekly_used,
        weekly_limit: weekly_limit,
        can_give: can_give
      }
    else
      %{
        daily_used: 0,
        daily_limit: 0,
        weekly_used: 0,
        weekly_limit: 0,
        can_give: false
      }
    end
  end
end
