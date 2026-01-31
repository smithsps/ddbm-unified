defmodule DdbmWeb.AdminLive do
  use DdbmWeb, :live_view

  alias Ddbm.Discord

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    cond do
      # Not logged in at all
      is_nil(current_user) ->
        socket =
          socket
          |> put_flash(:error, "You must be logged in to access the admin panel.")
          |> push_navigate(to: ~p"/")

        {:ok, socket}

      # Logged in but not authorized
      not is_admin?(current_user) ->
        socket =
          socket
          |> put_flash(:error, "You are not authorized to access the admin panel.")
          |> push_navigate(to: ~p"/dashboard")

        {:ok, socket}

      # Authorized admin
      true ->
        guild_id = Application.get_env(:ddbm_discord, :guild_id, "")

        socket =
          socket
          |> assign(:page_title, "Admin - Streaming Stats")
          |> assign(:guild_id, guild_id)
          |> assign(:view_mode, :active_streams)
          |> assign(:page, 1)
          |> assign(:per_page, 50)
          |> assign(:active_count, 0)
          |> assign(:history_count, 0)
          |> assign(:stats, %{})
          |> stream_configure(:streams, dom_id: &"stream-#{&1.id}")
          |> load_data()

        {:ok, socket}
    end
  end

  defp is_admin?(user) do
    admin_ids =
      Application.get_env(:ddbm_web, :admin_discord_ids, "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    user.discord_id in admin_ids
  end

  @impl true
  def handle_event("toggle_view_mode", %{"mode" => mode}, socket) do
    new_mode = String.to_existing_atom(mode)

    socket =
      socket
      |> assign(:view_mode, new_mode)
      |> assign(:page, 1)
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_data(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="flex h-[calc(100vh-4rem)]">
        <%!-- Sidebar --%>
        <aside class="w-64 bg-base-100 shadow-lg flex-shrink-0 hidden md:flex flex-col">
          <div class="p-6 border-b border-base-300">
            <h1 class="text-2xl font-bold text-base-content flex items-center gap-2">
              <span class="text-3xl">⚙️</span>
              Admin Panel
            </h1>
            <p class="text-sm text-base-content/60 mt-1">Server Management</p>
          </div>

          <nav class="flex-1 p-4 space-y-2">
            <div class="w-full text-left px-4 py-3 rounded-lg font-medium bg-primary text-primary-content shadow-md flex items-center gap-3">
              <span class="text-xl">📺</span>
              <span>Streaming</span>
            </div>
            <%!-- Future admin tools will go here --%>
          </nav>

          <div class="p-4 border-t border-base-300">
            <div class="text-xs text-base-content/50 text-center mb-2">
              More tools coming soon
            </div>
          </div>
        </aside>

        <%!-- Main Content --%>
        <main class="flex-1 overflow-y-auto bg-base-200">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <%!-- Page Header --%>
            <div class="flex items-center justify-between mb-8">
              <div>
                <h1 class="text-3xl font-bold text-base-content flex items-center gap-2">
                  <span class="text-4xl">📺</span>
                  Streaming Dashboard
                </h1>
                <p class="text-base-content/60 mt-1">Monitor and analyze streaming activity</p>
              </div>
              <button
                phx-click="refresh"
                class="px-4 py-2.5 rounded-lg bg-primary text-primary-content hover:bg-primary/90 transition-all shadow-sm font-medium flex items-center gap-2"
              >
                <span class="text-lg">🔄</span>
                <span class="hidden sm:inline">Refresh</span>
              </button>
            </div>

            <%!-- View Mode Tabs --%>
            <div class="mb-6">
              <div class="flex gap-2 border-b border-base-300">
                <button
                  phx-click="toggle_view_mode"
                  phx-value-mode="active_streams"
                  class={[
                    "px-4 py-3 font-medium transition-all border-b-2 flex items-center gap-2",
                    @view_mode == :active_streams &&
                      "border-primary text-primary",
                    @view_mode != :active_streams &&
                      "border-transparent text-base-content/60 hover:text-base-content hover:border-base-300"
                  ]}
                >
                  <span class="text-lg">🔴</span>
                  <span>Active Streams</span>
                  <span
                    :if={@active_count > 0}
                    class="px-2 py-0.5 rounded-full text-xs font-bold bg-primary text-primary-content"
                  >
                    {@active_count}
                  </span>
                </button>
                <button
                  phx-click="toggle_view_mode"
                  phx-value-mode="stream_history"
                  class={[
                    "px-4 py-3 font-medium transition-all border-b-2 flex items-center gap-2",
                    @view_mode == :stream_history &&
                      "border-primary text-primary",
                    @view_mode != :stream_history &&
                      "border-transparent text-base-content/60 hover:text-base-content hover:border-base-300"
                  ]}
                >
                  <span class="text-lg">📜</span>
                  <span>History</span>
                </button>
                <button
                  phx-click="toggle_view_mode"
                  phx-value-mode="statistics"
                  class={[
                    "px-4 py-3 font-medium transition-all border-b-2 flex items-center gap-2",
                    @view_mode == :statistics &&
                      "border-primary text-primary",
                    @view_mode != :statistics &&
                      "border-transparent text-base-content/60 hover:text-base-content hover:border-base-300"
                  ]}
                >
                  <span class="text-lg">📊</span>
                  <span>Statistics</span>
                </button>
              </div>
            </div>

            <%!-- Content --%>
            <%= case @view_mode do %>
              <% :active_streams -> %>
                <.active_streams_view streams={@streams} active_count={@active_count} />
              <% :stream_history -> %>
                <.stream_history_view streams={@streams} history_count={@history_count} guild_id={@guild_id} />
              <% :statistics -> %>
                <.statistics_view stats={@stats} />
            <% end %>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end

  defp active_streams_view(assigns) do
    ~H"""
    <div>
      <%= if @active_count == 0 do %>
        <div class="p-12 text-center rounded-lg bg-base-100 shadow-sm">
          <div class="text-6xl mb-4">📺</div>
          <p class="text-base-content/60 mb-2">No one is streaming right now</p>
          <p class="text-sm text-base-content/50">
            Active streams will appear here when members start streaming.
          </p>
        </div>
      <% else %>
        <div id="streams" phx-update="stream" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <.stream_card :for={{id, stream} <- @streams.streams} id={id} stream={stream} />
        </div>
      <% end %>
    </div>
    """
  end

  defp stream_history_view(assigns) do
    ~H"""
    <div>
      <%= if @history_count == 0 do %>
        <div class="p-12 text-center rounded-lg bg-base-100 shadow-sm">
          <div class="text-6xl mb-4">📜</div>
          <p class="text-base-content/60 mb-2">No stream history yet</p>
          <p class="text-sm text-base-content/50">
            Completed streams will appear here.
          </p>
        </div>
      <% else %>
        <div id="streams" phx-update="stream" class="space-y-3">
          <.stream_history_row :for={{id, stream} <- @streams.streams} id={id} stream={stream} guild_id={@guild_id} />
        </div>
      <% end %>
    </div>
    """
  end

  defp statistics_view(assigns) do
    ~H"""
    <div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <div class="p-6 rounded-xl bg-base-100 shadow-sm hover:shadow-md transition-shadow">
          <div class="text-4xl mb-3">📊</div>
          <div class="text-3xl font-bold text-base-content mb-1">{@stats.total_streams}</div>
          <div class="text-sm text-base-content/60">Total Streams</div>
        </div>

        <div class="p-6 rounded-xl bg-base-100 shadow-sm hover:shadow-md transition-shadow">
          <div class="text-4xl mb-3">⏱️</div>
          <div class="text-3xl font-bold text-base-content mb-1">{format_duration(@stats.total_duration)}</div>
          <div class="text-sm text-base-content/60">Total Stream Time</div>
        </div>

        <div class="p-6 rounded-xl bg-base-100 shadow-sm hover:shadow-md transition-shadow">
          <div class="text-4xl mb-3">📈</div>
          <div class="text-3xl font-bold text-base-content mb-1">{format_duration(@stats.avg_duration)}</div>
          <div class="text-sm text-base-content/60">Average Duration</div>
        </div>

        <div class="p-6 rounded-xl bg-base-100 shadow-sm hover:shadow-md transition-shadow">
          <div class="text-4xl mb-3">🎮</div>
          <div class="text-3xl font-bold text-base-content mb-1">{@stats.unique_streamers}</div>
          <div class="text-sm text-base-content/60">Unique Streamers</div>
        </div>

        <div class="p-6 rounded-xl bg-base-100 shadow-sm hover:shadow-md transition-shadow">
          <div class="text-4xl mb-3">🔴</div>
          <div class="text-3xl font-bold text-base-content mb-1">{@stats.active_now}</div>
          <div class="text-sm text-base-content/60">Currently Live</div>
        </div>

        <div class="p-6 rounded-xl bg-base-100 shadow-sm hover:shadow-md transition-shadow">
          <div class="text-4xl mb-3">🏆</div>
          <div class="text-3xl font-bold text-base-content mb-1">{@stats.most_popular_platform}</div>
          <div class="text-sm text-base-content/60">Top Platform</div>
        </div>
      </div>

      <%!-- Top Streamers --%>
      <%= if @stats.top_streamers != [] do %>
        <div>
          <h2 class="text-2xl font-bold text-base-content mb-4">Top Streamers</h2>
          <div class="space-y-3">
            <.top_streamer_row :for={{streamer, index} <- Enum.with_index(@stats.top_streamers, 1)} streamer={streamer} rank={index} guild_id={@stats.guild_id} />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp stream_card(assigns) do
    ~H"""
    <div class="p-6 rounded-xl bg-base-100 shadow-sm hover:shadow-md transition-shadow">
      <div class="flex items-start justify-between mb-3">
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 bg-red-500 rounded-full animate-pulse"></div>
          <span class="text-xs font-medium text-red-500 uppercase">Live</span>
        </div>
        <span class="text-xs px-2 py-1 bg-base-300 rounded-full">{@stream.platform}</span>
      </div>

      <h3 class="font-bold text-lg text-base-content mb-2 line-clamp-2">
        {@stream.game_name || @stream.stream_name || "Streaming"}
      </h3>

      <div class="flex items-center gap-2 mb-3">
        <div class="text-sm text-base-content/60">
          {get_display_name(@stream.discord_id, @stream.guild_id)}
        </div>
      </div>

      <%= if @stream.details do %>
        <p class="text-sm text-base-content/70 mb-3 line-clamp-2">{@stream.details}</p>
      <% end %>

      <div class="flex items-center justify-between text-xs text-base-content/50">
        <span>Started {format_relative_time(@stream.started_at)}</span>
        <%= if @stream.stream_url do %>
          <a
            href={@stream.stream_url}
            target="_blank"
            class="text-primary hover:text-primary/80"
          >
            Watch →
          </a>
        <% end %>
      </div>
    </div>
    """
  end

  defp stream_history_row(assigns) do
    ~H"""
    <div class="p-4 rounded-lg bg-base-100 shadow-sm hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between">
        <div class="flex-1">
          <div class="flex items-center gap-3">
            <div class="font-semibold text-base-content">
              {get_display_name(@stream.discord_id, @guild_id)}
            </div>
            <div class="text-sm text-base-content/60">
              streamed <span class="font-medium">{@stream.game_name || @stream.stream_name || "Unknown"}</span>
            </div>
          </div>
          <div class="flex items-center gap-4 mt-2 text-xs text-base-content/50">
            <span>🕐 {format_datetime(@stream.started_at)}</span>
            <span>⏱️ {calculate_duration(@stream.started_at, @stream.ended_at)}</span>
            <span class="px-2 py-1 bg-base-300 rounded">{@stream.platform}</span>
          </div>
        </div>
        <%= if @stream.stream_url do %>
          <a
            href={@stream.stream_url}
            target="_blank"
            class="text-primary hover:text-primary/80 text-sm"
          >
            View →
          </a>
        <% end %>
      </div>
    </div>
    """
  end

  defp top_streamer_row(assigns) do
    ~H"""
    <div class="p-6 rounded-xl bg-base-100 shadow-sm hover:shadow-md transition-all">
      <div class="flex items-center gap-4">
        <div class={[
          "w-12 h-12 rounded-full flex items-center justify-center font-bold text-xl flex-shrink-0",
          @rank == 1 && "bg-yellow-500 text-yellow-900",
          @rank == 2 && "bg-gray-400 text-gray-900",
          @rank == 3 && "bg-amber-600 text-amber-900",
          @rank > 3 && "bg-base-300 text-base-content"
        ]}>
          <%= if @rank <= 3 do %>
            <%= case @rank do %>
              <% 1 -> %> 🥇
              <% 2 -> %> 🥈
              <% 3 -> %> 🥉
            <% end %>
          <% else %>
            #{@rank}
          <% end %>
        </div>
        <div class="flex-1 min-w-0">
          <div class="font-bold text-lg text-base-content mb-1 truncate">
            {get_display_name(@streamer.discord_id, @guild_id)}
          </div>
          <div class="flex flex-wrap items-center gap-3 text-sm">
            <div class="flex items-center gap-1.5 text-base-content/70">
              <span class="font-medium">📊</span>
              <span>{@streamer.total_streams} streams</span>
            </div>
            <div class="flex items-center gap-1.5 text-base-content/70">
              <span class="font-medium">⏱️</span>
              <span>{format_duration(@streamer.total_seconds)} total</span>
            </div>
            <div class="flex items-center gap-1.5 text-base-content/70">
              <span class="font-medium">📈</span>
              <span>{format_duration(@streamer.average_seconds)} avg</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp load_data(socket) do
    guild_id = socket.assigns.guild_id
    view_mode = socket.assigns.view_mode

    case view_mode do
      :active_streams ->
        streams = Discord.get_active_streams(guild_id)

        socket
        |> assign(:active_count, length(streams))
        |> stream(:streams, streams, reset: true)

      :stream_history ->
        history = Discord.get_guild_stream_history(guild_id, limit: 100)

        socket
        |> assign(:active_count, length(Discord.get_active_streams(guild_id)))
        |> assign(:history_count, length(history))
        |> stream(:streams, history, reset: true)

      :statistics ->
        active_streams = Discord.get_active_streams(guild_id)
        history = Discord.get_guild_stream_history(guild_id, limit: 1000)

        stats = calculate_statistics(guild_id, active_streams, history)

        socket
        |> assign(:active_count, length(active_streams))
        |> assign(:stats, stats)
    end
  end

  defp calculate_statistics(guild_id, active_streams, history) do
    total_streams = length(history)

    total_seconds =
      history
      |> Enum.map(fn stream ->
        DateTime.diff(stream.ended_at, stream.started_at, :second)
      end)
      |> Enum.sum()

    avg_seconds = if total_streams > 0, do: div(total_seconds, total_streams), else: 0

    unique_streamers =
      history
      |> Enum.map(& &1.discord_id)
      |> Enum.uniq()
      |> length()

    platform_counts =
      history
      |> Enum.frequencies_by(& &1.platform)

    most_popular_platform =
      if platform_counts == %{} do
        "N/A"
      else
        {platform, _count} = Enum.max_by(platform_counts, fn {_k, v} -> v end)
        String.capitalize(platform)
      end

    top_streamers =
      history
      |> Enum.group_by(& &1.discord_id)
      |> Enum.map(fn {discord_id, streams} ->
        total = Enum.count(streams)

        duration =
          streams
          |> Enum.map(fn s -> DateTime.diff(s.ended_at, s.started_at, :second) end)
          |> Enum.sum()

        avg = if total > 0, do: div(duration, total), else: 0

        %{
          discord_id: discord_id,
          total_streams: total,
          total_seconds: duration,
          average_seconds: avg
        }
      end)
      |> Enum.sort_by(& &1.total_seconds, :desc)
      |> Enum.take(10)

    %{
      guild_id: guild_id,
      total_streams: total_streams,
      total_duration: total_seconds,
      avg_duration: avg_seconds,
      unique_streamers: unique_streamers,
      active_now: length(active_streams),
      most_popular_platform: most_popular_platform,
      top_streamers: top_streamers
    }
  end

  defp get_display_name(discord_id, guild_id) do
    Discord.get_display_name(discord_id, guild_id) || "Unknown User"
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp format_relative_time(datetime) do
    seconds_ago = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      seconds_ago < 60 -> "just now"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)}m ago"
      seconds_ago < 86400 -> "#{div(seconds_ago, 3600)}h ago"
      true -> "#{div(seconds_ago, 86400)}d ago"
    end
  end

  defp calculate_duration(started_at, ended_at) do
    seconds = DateTime.diff(ended_at, started_at, :second)
    format_duration(seconds)
  end

  defp format_duration(seconds) when seconds < 60 do
    "#{seconds}s"
  end

  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}m #{secs}s"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{minutes}m"
  end
end
