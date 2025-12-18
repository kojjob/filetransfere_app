defmodule FiletransferWeb.Owner.AnalyticsLive do
  @moduledoc """
  LiveView for project owners to view platform analytics.
  Shows usage metrics, trends, and insights.
  """
  use FiletransferWeb, :live_view

  alias FiletransferCore.Usage

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Analytics")
      |> assign(:active_tab, "analytics")
      |> assign(:time_range, "30d")
      |> assign(:metrics, load_metrics("30d"))
      |> assign(:chart_data, load_chart_data("30d"))

    {:ok, socket, layout: {FiletransferWeb.Layouts, :owner_dashboard}}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    time_range = Map.get(params, "range", "30d")

    socket =
      socket
      |> assign(:time_range, time_range)
      |> assign(:metrics, load_metrics(time_range))
      |> assign(:chart_data, load_chart_data(time_range))

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header Controls --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div class="flex items-center gap-3">
          <.time_range_selector current={@time_range} />
        </div>
        <button
          type="button"
          phx-click="export_analytics"
          class="obsidian-btn obsidian-btn-ghost"
        >
          <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
          <span>Export</span>
        </button>
      </div>

      <%!-- Key Metrics Grid --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <.metric_card
          title="Total Users"
          value={@metrics.total_users}
          change={@metrics.users_change}
          trend={@metrics.users_trend}
          icon="hero-users"
          color="amber"
        />
        <.metric_card
          title="Total Transfers"
          value={@metrics.total_transfers}
          change={@metrics.transfers_change}
          trend={@metrics.transfers_trend}
          icon="hero-arrow-up-tray"
          color="emerald"
        />
        <.metric_card
          title="Storage Used"
          value={format_bytes(@metrics.total_storage)}
          change={@metrics.storage_change}
          trend={@metrics.storage_trend}
          icon="hero-server-stack"
          color="sky"
        />
        <.metric_card
          title="Active Shares"
          value={@metrics.active_shares}
          change={@metrics.shares_change}
          trend={@metrics.shares_trend}
          icon="hero-link"
          color="coral"
        />
      </div>

      <%!-- Charts Row --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Usage Trend Chart --%>
        <div class="obsidian-card rounded-xl p-5">
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center gap-3">
              <div class="obsidian-icon-box">
                <.icon name="hero-chart-bar" class="w-4 h-4 obsidian-accent-amber" />
              </div>
              <h2 class="text-sm font-semibold obsidian-text-primary">Usage Trend</h2>
            </div>
            <div class="flex items-center gap-4 text-xs">
              <span class="flex items-center gap-1.5">
                <span class="w-2 h-2 bg-emerald-400 rounded-full"></span>
                <span class="obsidian-text-secondary">Transfers</span>
              </span>
              <span class="flex items-center gap-1.5">
                <span class="w-2 h-2 bg-sky-400 rounded-full"></span>
                <span class="obsidian-text-secondary">Downloads</span>
              </span>
            </div>
          </div>
          <div class="h-56 flex items-center justify-center">
            <div class="text-center">
              <div class="obsidian-icon-box mx-auto mb-3 w-12 h-12">
                <.icon name="hero-chart-bar" class="w-6 h-6 obsidian-text-tertiary" />
              </div>
              <p class="text-sm obsidian-text-secondary">Chart visualization coming soon</p>
              <p class="text-xs obsidian-text-tertiary mt-1">Data available for export</p>
            </div>
          </div>
        </div>

        <%!-- User Growth Chart --%>
        <div class="obsidian-card rounded-xl p-5">
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center gap-3">
              <div class="obsidian-icon-box">
                <.icon name="hero-user-group" class="w-4 h-4 obsidian-accent-emerald" />
              </div>
              <h2 class="text-sm font-semibold obsidian-text-primary">User Growth</h2>
            </div>
            <div class="flex items-center gap-4 text-xs">
              <span class="flex items-center gap-1.5">
                <span class="w-2 h-2 bg-amber-400 rounded-full"></span>
                <span class="obsidian-text-secondary">New Users</span>
              </span>
              <span class="flex items-center gap-1.5">
                <span class="w-2 h-2 bg-orange-400 rounded-full"></span>
                <span class="obsidian-text-secondary">Active Users</span>
              </span>
            </div>
          </div>
          <div class="h-56 flex items-center justify-center">
            <div class="text-center">
              <div class="obsidian-icon-box mx-auto mb-3 w-12 h-12">
                <.icon name="hero-user-group" class="w-6 h-6 obsidian-text-tertiary" />
              </div>
              <p class="text-sm obsidian-text-secondary">Chart visualization coming soon</p>
              <p class="text-xs obsidian-text-tertiary mt-1">Data available for export</p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Detailed Stats --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Top Users by Storage --%>
        <div class="obsidian-card rounded-xl overflow-hidden">
          <div class="px-5 py-4 border-b border-white/5 [[data-theme=light]_&]:border-black/5">
            <div class="flex items-center gap-3">
              <div class="obsidian-icon-box">
                <.icon name="hero-server-stack" class="w-4 h-4 obsidian-accent-sky" />
              </div>
              <h3 class="text-sm font-semibold obsidian-text-primary">Top by Storage</h3>
            </div>
          </div>
          <div class="divide-y divide-white/5 [[data-theme=light]_&]:divide-black/5">
            <%= if Enum.empty?(@chart_data.top_users_storage) do %>
              <div class="p-8 text-center">
                <div class="obsidian-icon-box mx-auto mb-3 w-10 h-10">
                  <.icon name="hero-server-stack" class="w-5 h-5 obsidian-text-tertiary" />
                </div>
                <p class="text-sm obsidian-text-secondary">No data available</p>
              </div>
            <% else %>
              <%= for {user, index} <- Enum.with_index(@chart_data.top_users_storage) do %>
                <.top_user_row user={user} index={index} metric_type="storage" />
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- Top Users by Transfers --%>
        <div class="obsidian-card rounded-xl overflow-hidden">
          <div class="px-5 py-4 border-b border-white/5 [[data-theme=light]_&]:border-black/5">
            <div class="flex items-center gap-3">
              <div class="obsidian-icon-box">
                <.icon name="hero-arrow-up-tray" class="w-4 h-4 obsidian-accent-coral" />
              </div>
              <h3 class="text-sm font-semibold obsidian-text-primary">Top by Transfers</h3>
            </div>
          </div>
          <div class="divide-y divide-white/5 [[data-theme=light]_&]:divide-black/5">
            <%= if Enum.empty?(@chart_data.top_users_transfers) do %>
              <div class="p-8 text-center">
                <div class="obsidian-icon-box mx-auto mb-3 w-10 h-10">
                  <.icon name="hero-arrow-up-tray" class="w-5 h-5 obsidian-text-tertiary" />
                </div>
                <p class="text-sm obsidian-text-secondary">No data available</p>
              </div>
            <% else %>
              <%= for {user, index} <- Enum.with_index(@chart_data.top_users_transfers) do %>
                <.top_user_row user={user} index={index} metric_type="transfers" />
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- System Health --%>
        <div class="obsidian-card rounded-xl overflow-hidden">
          <div class="px-5 py-4 border-b border-white/5 [[data-theme=light]_&]:border-black/5">
            <div class="flex items-center gap-3">
              <div class="obsidian-icon-box">
                <.icon name="hero-heart" class="w-4 h-4 obsidian-accent-amber" />
              </div>
              <h3 class="text-sm font-semibold obsidian-text-primary">System Health</h3>
              <span class="obsidian-badge obsidian-badge-emerald ml-auto">Healthy</span>
            </div>
          </div>
          <div class="p-5 space-y-4">
            <.health_indicator label="API Response" value="45ms" status="good" threshold="<100ms" />
            <.health_indicator label="Storage" value="23%" status="good" threshold="<80%" />
            <.health_indicator label="DB Connections" value="12/100" status="good" threshold="<80" />
            <.health_indicator label="Jobs Queue" value="3" status="good" threshold="<50" />
            <.health_indicator label="Error Rate" value="0.02%" status="good" threshold="<1%" />
          </div>
        </div>
      </div>

      <%!-- Activity Timeline --%>
      <div class="obsidian-card rounded-xl overflow-hidden">
        <div class="px-5 py-4 flex items-center justify-between border-b border-white/5 [[data-theme=light]_&]:border-black/5">
          <div class="flex items-center gap-3">
            <div class="obsidian-icon-box">
              <.icon name="hero-clock" class="w-4 h-4 obsidian-accent-emerald" />
            </div>
            <h2 class="text-sm font-semibold obsidian-text-primary">Recent Activity</h2>
          </div>
          <div class="flex items-center gap-1.5">
            <span class="obsidian-live-dot"></span>
            <span class="text-[11px] obsidian-text-tertiary">Live</span>
          </div>
        </div>
        <div class="divide-y divide-white/5 [[data-theme=light]_&]:divide-black/5">
          <%= if Enum.empty?(@chart_data.recent_activity) do %>
            <div class="p-10 text-center">
              <div class="obsidian-icon-box mx-auto mb-3 w-12 h-12">
                <.icon name="hero-clock" class="w-6 h-6 obsidian-text-tertiary" />
              </div>
              <p class="text-sm obsidian-text-secondary">No recent activity</p>
              <p class="text-xs obsidian-text-tertiary mt-1">Activity will appear here</p>
            </div>
          <% else %>
            <%= for activity <- @chart_data.recent_activity do %>
              <.activity_item activity={activity} />
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Components

  defp time_range_selector(assigns) do
    ranges = [
      {"7d", "7D"},
      {"30d", "30D"},
      {"90d", "90D"},
      {"1y", "1Y"}
    ]

    assigns = assign(assigns, :ranges, ranges)

    ~H"""
    <div class="flex bg-white/5 [[data-theme=light]_&]:bg-black/5 rounded-lg p-0.5">
      <%= for {value, label} <- @ranges do %>
        <.link
          patch={~p"/owner/analytics?range=#{value}"}
          class={[
            "px-3 py-1.5 text-xs font-medium rounded-md transition-all",
            if(@current == value,
              do: "bg-white/10 [[data-theme=light]_&]:bg-black/10 obsidian-text-primary",
              else: "obsidian-text-tertiary hover:obsidian-text-secondary"
            )
          ]}
        >
          {label}
        </.link>
      <% end %>
    </div>
    """
  end

  defp metric_card(assigns) do
    icon_colors = %{
      "amber" => "obsidian-accent-amber",
      "emerald" => "obsidian-accent-emerald",
      "sky" => "obsidian-accent-sky",
      "coral" => "obsidian-accent-coral"
    }

    icon_bg = %{
      "amber" => "bg-[#d4af37]/10",
      "emerald" => "bg-[#2dd4bf]/10",
      "sky" => "bg-[#38bdf8]/10",
      "coral" => "bg-[#fb923c]/10"
    }

    assigns =
      assigns
      |> assign(:icon_color, Map.get(icon_colors, assigns.color, "obsidian-text-secondary"))
      |> assign(:icon_bg, Map.get(icon_bg, assigns.color, "bg-white/5"))

    ~H"""
    <div class="obsidian-card rounded-xl p-5 group">
      <div class="flex items-start justify-between mb-4">
        <div class={"w-10 h-10 rounded-xl #{@icon_bg} flex items-center justify-center transition-transform group-hover:scale-105"}>
          <.icon name={@icon} class={"w-5 h-5 #{@icon_color}"} />
        </div>
        <%= if @change do %>
          <div class="flex items-center gap-1">
            <.icon
              name={if @trend == "up", do: "hero-arrow-trending-up", else: "hero-arrow-trending-down"}
              class={"w-3.5 h-3.5 #{if @trend == "up", do: "obsidian-accent-emerald", else: "obsidian-accent-coral"}"}
            />
            <span class={"text-xs font-medium #{if @trend == "up", do: "obsidian-accent-emerald", else: "obsidian-accent-coral"}"}>
              {@change}%
            </span>
          </div>
        <% end %>
      </div>
      <p class="obsidian-stat text-2xl obsidian-text-primary">{@value}</p>
      <p class="text-xs obsidian-text-tertiary mt-1 uppercase tracking-wider">{@title}</p>
    </div>
    """
  end

  defp top_user_row(assigns) do
    ~H"""
    <div class="obsidian-table-row px-5 py-3 flex items-center gap-3">
      <div class="w-6 h-6 rounded-md bg-[#d4af37]/10 flex items-center justify-center text-xs font-semibold obsidian-accent-amber">
        {@index + 1}
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium obsidian-text-primary truncate">{@user.name || @user.email}</p>
        <p class="text-xs obsidian-text-tertiary">
          <%= if @metric_type == "storage" do %>
            {format_bytes(@user.storage_used || 0)}
          <% else %>
            {pluralize(@user.transfer_count || 0, "transfer")}
          <% end %>
        </p>
      </div>
    </div>
    """
  end

  defp health_indicator(assigns) do
    status_badge = %{
      "good" => "obsidian-badge-emerald",
      "warning" => "obsidian-badge-amber",
      "critical" => "bg-red-500/15 text-red-400 border border-red-500/20"
    }

    assigns = assign(assigns, :status_badge, Map.get(status_badge, assigns.status, "obsidian-badge-slate"))

    ~H"""
    <div class="flex items-center justify-between">
      <div>
        <p class="text-sm obsidian-text-primary">{@label}</p>
        <p class="text-[11px] obsidian-text-tertiary">{@threshold}</p>
      </div>
      <span class={"obsidian-badge #{@status_badge}"}>
        {@value}
      </span>
    </div>
    """
  end

  defp activity_item(assigns) do
    ~H"""
    <div class="obsidian-table-row px-5 py-4 flex items-center gap-4">
      <div class={"w-9 h-9 rounded-lg flex items-center justify-center #{activity_icon_bg(@activity.type)}"}>
        <.icon
          name={activity_icon(@activity.type)}
          class={"w-4 h-4 #{activity_icon_color(@activity.type)}"}
        />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm obsidian-text-primary">{@activity.description}</p>
        <p class="text-xs obsidian-text-tertiary mt-0.5">{format_datetime(@activity.inserted_at)}</p>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("export_analytics", _params, socket) do
    {:noreply,
     put_flash(socket, :info, "Generating analytics report... Download will start shortly.")}
  end

  # Helper Functions

  defp load_metrics(time_range) do
    base_metrics = %{
      total_users: 0,
      users_change: nil,
      users_trend: "up",
      total_transfers: 0,
      transfers_change: nil,
      transfers_trend: "up",
      total_storage: 0,
      storage_change: nil,
      storage_trend: "up",
      active_shares: 0,
      shares_change: nil,
      shares_trend: "up"
    }

    case function_exported?(Usage, :get_platform_metrics, 1) do
      true ->
        {:ok, metrics} = Usage.get_platform_metrics(time_range)
        Map.merge(base_metrics, metrics)

      false ->
        base_metrics
    end
  rescue
    _ ->
      %{
        total_users: 0,
        users_change: nil,
        users_trend: "up",
        total_transfers: 0,
        transfers_change: nil,
        transfers_trend: "up",
        total_storage: 0,
        storage_change: nil,
        storage_trend: "up",
        active_shares: 0,
        shares_change: nil,
        shares_trend: "up"
      }
  end

  defp load_chart_data(_time_range) do
    %{
      top_users_storage: [],
      top_users_transfers: [],
      recent_activity: []
    }
  end

  defp format_bytes(nil), do: "0 B"
  defp format_bytes(0), do: "0 B"

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_099_511_627_776 -> "#{Float.round(bytes / 1_099_511_627_776, 1)} TB"
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_datetime(nil), do: "N/A"
  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")

  defp pluralize(count, word) when count == 1, do: "#{count} #{word}"
  defp pluralize(count, word), do: "#{count} #{word}s"

  defp activity_icon(type) do
    case type do
      :user_registered -> "hero-user-plus"
      :transfer_completed -> "hero-arrow-up-tray"
      :share_created -> "hero-link"
      :user_upgraded -> "hero-arrow-up-circle"
      _ -> "hero-clock"
    end
  end

  defp activity_icon_bg(type) do
    case type do
      :user_registered -> "bg-[#d4af37]/10"
      :transfer_completed -> "bg-[#2dd4bf]/10"
      :share_created -> "bg-[#38bdf8]/10"
      :user_upgraded -> "bg-orange-500/10"
      _ -> "bg-white/5 [[data-theme=light]_&]:bg-black/5"
    end
  end

  defp activity_icon_color(type) do
    case type do
      :user_registered -> "obsidian-accent-amber"
      :transfer_completed -> "obsidian-accent-emerald"
      :share_created -> "obsidian-accent-sky"
      :user_upgraded -> "text-orange-400"
      _ -> "obsidian-text-secondary"
    end
  end
end
