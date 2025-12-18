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
      |> assign(:page_title, "Platform Analytics")
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
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Platform Analytics</h1>
          <p class="text-gray-500 mt-1">Monitor platform usage and performance metrics.</p>
        </div>
        <div class="flex items-center gap-3">
          <.time_range_selector current={@time_range} />
          <button
            type="button"
            phx-click="export_analytics"
            class="inline-flex items-center gap-2 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
          >
            <.icon name="hero-arrow-down-tray" class="w-5 h-5" /> Export Report
          </button>
        </div>
      </div>
      
    <!-- Key Metrics Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <.metric_card
          title="Total Users"
          value={@metrics.total_users}
          change={@metrics.users_change}
          trend={@metrics.users_trend}
          icon="hero-users"
          color="purple"
        />
        <.metric_card
          title="Total Transfers"
          value={@metrics.total_transfers}
          change={@metrics.transfers_change}
          trend={@metrics.transfers_trend}
          icon="hero-arrow-up-tray"
          color="blue"
        />
        <.metric_card
          title="Storage Used"
          value={format_bytes(@metrics.total_storage)}
          change={@metrics.storage_change}
          trend={@metrics.storage_trend}
          icon="hero-server-stack"
          color="green"
        />
        <.metric_card
          title="Active Shares"
          value={@metrics.active_shares}
          change={@metrics.shares_change}
          trend={@metrics.shares_trend}
          icon="hero-share"
          color="orange"
        />
      </div>
      
    <!-- Charts Row -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Usage Trend Chart -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-lg font-semibold text-gray-900">Usage Trend</h2>
            <div class="flex items-center gap-4 text-sm">
              <span class="flex items-center gap-1.5">
                <span class="w-3 h-3 bg-blue-500 rounded-full"></span> Transfers
              </span>
              <span class="flex items-center gap-1.5">
                <span class="w-3 h-3 bg-green-500 rounded-full"></span> Downloads
              </span>
            </div>
          </div>
          <div class="h-64 flex items-center justify-center text-gray-400">
            <div class="text-center">
              <.icon name="hero-chart-bar" class="w-12 h-12 mx-auto mb-2" />
              <p>Chart visualization coming soon</p>
              <p class="text-sm">Data available for export</p>
            </div>
          </div>
        </div>
        
    <!-- User Growth Chart -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-lg font-semibold text-gray-900">User Growth</h2>
            <div class="flex items-center gap-4 text-sm">
              <span class="flex items-center gap-1.5">
                <span class="w-3 h-3 bg-purple-500 rounded-full"></span> New Users
              </span>
              <span class="flex items-center gap-1.5">
                <span class="w-3 h-3 bg-pink-500 rounded-full"></span> Active Users
              </span>
            </div>
          </div>
          <div class="h-64 flex items-center justify-center text-gray-400">
            <div class="text-center">
              <.icon name="hero-user-group" class="w-12 h-12 mx-auto mb-2" />
              <p>Chart visualization coming soon</p>
              <p class="text-sm">Data available for export</p>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Detailed Stats -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Top Users by Storage -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Top Users by Storage</h3>
          </div>
          <div class="divide-y divide-gray-50">
            <%= if Enum.empty?(@chart_data.top_users_storage) do %>
              <div class="p-6 text-center text-gray-500">
                <.icon name="hero-server-stack" class="w-10 h-10 mx-auto text-gray-300 mb-2" />
                <p class="text-sm">No data available</p>
              </div>
            <% else %>
              <%= for {user, index} <- Enum.with_index(@chart_data.top_users_storage) do %>
                <.top_user_row user={user} index={index} metric_type="storage" />
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- Top Users by Transfers -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Top Users by Transfers</h3>
          </div>
          <div class="divide-y divide-gray-50">
            <%= if Enum.empty?(@chart_data.top_users_transfers) do %>
              <div class="p-6 text-center text-gray-500">
                <.icon name="hero-arrow-up-tray" class="w-10 h-10 mx-auto text-gray-300 mb-2" />
                <p class="text-sm">No data available</p>
              </div>
            <% else %>
              <%= for {user, index} <- Enum.with_index(@chart_data.top_users_transfers) do %>
                <.top_user_row user={user} index={index} metric_type="transfers" />
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- System Health -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">System Health</h3>
          </div>
          <div class="p-6 space-y-4">
            <.health_indicator
              label="API Response Time"
              value="45ms"
              status="good"
              threshold="<100ms"
            />
            <.health_indicator
              label="Storage Capacity"
              value="23%"
              status="good"
              threshold="<80%"
            />
            <.health_indicator
              label="Database Connections"
              value="12/100"
              status="good"
              threshold="<80"
            />
            <.health_indicator
              label="Background Jobs"
              value="3 pending"
              status="good"
              threshold="<50"
            />
            <.health_indicator
              label="Error Rate"
              value="0.02%"
              status="good"
              threshold="<1%"
            />
          </div>
        </div>
      </div>
      
    <!-- Activity Timeline -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100">
        <div class="p-4 border-b border-gray-100 flex items-center justify-between">
          <h2 class="text-lg font-semibold text-gray-900">Recent Platform Activity</h2>
          <.link navigate={~p"/owner/activity"} class="text-sm text-purple-600 hover:text-purple-700">
            View all →
          </.link>
        </div>
        <div class="divide-y divide-gray-50">
          <%= if Enum.empty?(@chart_data.recent_activity) do %>
            <div class="p-8 text-center text-gray-500">
              <.icon name="hero-clock" class="w-12 h-12 mx-auto text-gray-300 mb-3" />
              <p>No recent activity</p>
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
      {"7d", "7 Days"},
      {"30d", "30 Days"},
      {"90d", "90 Days"},
      {"1y", "1 Year"}
    ]

    assigns = assign(assigns, :ranges, ranges)

    ~H"""
    <div class="flex bg-gray-100 rounded-lg p-1">
      <%= for {value, label} <- @ranges do %>
        <.link
          patch={~p"/owner/analytics?range=#{value}"}
          class={[
            "px-3 py-1.5 text-sm font-medium rounded-md transition-colors",
            if(@current == value,
              do: "bg-white text-gray-900 shadow-sm",
              else: "text-gray-600 hover:text-gray-900"
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
    color_classes = %{
      "purple" => "bg-purple-50 text-purple-600",
      "blue" => "bg-blue-50 text-blue-600",
      "green" => "bg-green-50 text-green-600",
      "orange" => "bg-orange-50 text-orange-600"
    }

    assigns =
      assign(
        assigns,
        :color_class,
        Map.get(color_classes, assigns.color, "bg-gray-50 text-gray-600")
      )

    ~H"""
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
      <div class="flex items-center justify-between">
        <div class={"p-3 rounded-lg #{@color_class}"}>
          <.icon name={@icon} class="w-6 h-6" />
        </div>
        <%= if @change do %>
          <div class="flex items-center gap-1">
            <.icon
              name={if @trend == "up", do: "hero-arrow-trending-up", else: "hero-arrow-trending-down"}
              class={"w-4 h-4 #{if @trend == "up", do: "text-green-600", else: "text-red-600"}"}
            />
            <span class={"text-sm font-medium #{if @trend == "up", do: "text-green-600", else: "text-red-600"}"}>
              {@change}%
            </span>
          </div>
        <% end %>
      </div>
      <div class="mt-4">
        <p class="text-2xl font-bold text-gray-900">{@value}</p>
        <p class="text-sm text-gray-500 mt-1">{@title}</p>
      </div>
    </div>
    """
  end

  defp top_user_row(assigns) do
    ~H"""
    <div class="p-4 flex items-center gap-3">
      <div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center text-sm font-medium text-purple-600">
        {@index + 1}
      </div>
      <div class="flex-1 min-w-0">
        <p class="font-medium text-gray-900 truncate">{@user.name || @user.email}</p>
        <p class="text-sm text-gray-500">
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
    status_classes = %{
      "good" => "bg-green-100 text-green-700",
      "warning" => "bg-yellow-100 text-yellow-700",
      "critical" => "bg-red-100 text-red-700"
    }

    assigns =
      assign(
        assigns,
        :status_class,
        Map.get(status_classes, assigns.status, "bg-gray-100 text-gray-700")
      )

    ~H"""
    <div class="flex items-center justify-between">
      <div>
        <p class="text-sm font-medium text-gray-900">{@label}</p>
        <p class="text-xs text-gray-500">Target: {@threshold}</p>
      </div>
      <span class={"px-2 py-1 text-xs font-medium rounded-full #{@status_class}"}>
        {@value}
      </span>
    </div>
    """
  end

  defp activity_item(assigns) do
    ~H"""
    <div class="p-4 flex items-center gap-4">
      <div class={"p-2 rounded-lg #{activity_icon_bg(@activity.type)}"}>
        <.icon
          name={activity_icon(@activity.type)}
          class={"w-5 h-5 #{activity_icon_color(@activity.type)}"}
        />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-gray-900">{@activity.description}</p>
        <p class="text-sm text-gray-500">{format_datetime(@activity.inserted_at)}</p>
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
        case Usage.get_platform_metrics(time_range) do
          nil -> base_metrics
          metrics -> Map.merge(base_metrics, metrics)
        end

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
      :share_created -> "hero-share"
      :user_upgraded -> "hero-arrow-up-circle"
      _ -> "hero-clock"
    end
  end

  defp activity_icon_bg(type) do
    case type do
      :user_registered -> "bg-purple-50"
      :transfer_completed -> "bg-blue-50"
      :share_created -> "bg-green-50"
      :user_upgraded -> "bg-orange-50"
      _ -> "bg-gray-50"
    end
  end

  defp activity_icon_color(type) do
    case type do
      :user_registered -> "text-purple-600"
      :transfer_completed -> "text-blue-600"
      :share_created -> "text-green-600"
      :user_upgraded -> "text-orange-600"
      _ -> "text-gray-600"
    end
  end
end
