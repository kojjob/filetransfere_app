defmodule FiletransferWeb.Owner.OwnerDashboardLive do
  @moduledoc """
  Main dashboard view for project owners.
  Shows platform-wide overview, statistics, and recent activity.
  """
  use FiletransferWeb, :live_view

  alias FiletransferCore.Accounts

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Owner Dashboard")
      |> assign(:platform_stats, load_platform_stats())
      |> assign(:recent_users, load_recent_users())
      |> assign(:recent_activity, load_recent_activity())

    {:ok, socket, layout: {FiletransferWeb.Layouts, :owner_dashboard}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Welcome Header -->
      <div class="bg-gradient-to-r from-purple-600 to-pink-600 rounded-xl p-6 text-white">
        <div class="flex items-center gap-2 mb-2">
          <.icon name="hero-shield-check" class="w-6 h-6" />
          <span class="text-sm font-medium text-purple-200">Project Owner</span>
        </div>
        <h1 class="text-2xl font-bold">Platform Overview</h1>
        <p class="text-purple-100 mt-1">Monitor and manage your file transfer platform.</p>
      </div>
      
    <!-- Platform Stats -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <.stat_card
          title="Total Users"
          value={@platform_stats.total_users}
          change={@platform_stats.users_change}
          icon="hero-users"
          color="purple"
        />
        <.stat_card
          title="Total Transfers"
          value={@platform_stats.total_transfers}
          change={@platform_stats.transfers_change}
          icon="hero-arrow-up-tray"
          color="blue"
        />
        <.stat_card
          title="Active Shares"
          value={@platform_stats.active_shares}
          change={@platform_stats.shares_change}
          icon="hero-share"
          color="green"
        />
        <.stat_card
          title="Storage Used"
          value={format_bytes(@platform_stats.total_storage)}
          change={@platform_stats.storage_change}
          icon="hero-server-stack"
          color="orange"
        />
      </div>
      
    <!-- Main Content Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Recent Users -->
        <div class="lg:col-span-2 bg-white rounded-xl shadow-sm border border-gray-100">
          <div class="p-4 border-b border-gray-100 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-900">Recent Users</h2>
            <.link navigate={~p"/owner/users"} class="text-sm text-purple-600 hover:text-purple-700">
              View all →
            </.link>
          </div>
          <div class="divide-y divide-gray-50">
            <%= if Enum.empty?(@recent_users) do %>
              <div class="p-8 text-center text-gray-500">
                <.icon name="hero-users" class="w-12 h-12 mx-auto text-gray-300 mb-3" />
                <p>No users yet</p>
              </div>
            <% else %>
              <%= for user <- @recent_users do %>
                <.user_row user={user} />
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- Quick Stats & Actions -->
        <div class="space-y-6">
          <!-- User Distribution -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
            <h3 class="font-semibold text-gray-900 mb-4">User Distribution</h3>
            <div class="space-y-3">
              <.distribution_bar
                label="Free"
                value={@platform_stats.users_by_tier["free"] || 0}
                total={@platform_stats.total_users}
                color="gray"
              />
              <.distribution_bar
                label="Pro"
                value={@platform_stats.users_by_tier["pro"] || 0}
                total={@platform_stats.total_users}
                color="blue"
              />
              <.distribution_bar
                label="Business"
                value={@platform_stats.users_by_tier["business"] || 0}
                total={@platform_stats.total_users}
                color="purple"
              />
              <.distribution_bar
                label="Enterprise"
                value={@platform_stats.users_by_tier["enterprise"] || 0}
                total={@platform_stats.total_users}
                color="orange"
              />
            </div>
          </div>
          
    <!-- Quick Actions -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
            <h3 class="font-semibold text-gray-900 mb-4">Quick Actions</h3>
            <div class="space-y-2">
              <.link
                navigate={~p"/owner/users"}
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <div class="p-2 bg-purple-100 rounded-lg">
                  <.icon name="hero-user-plus" class="w-5 h-5 text-purple-600" />
                </div>
                <span class="font-medium text-gray-700">Manage Users</span>
              </.link>
              <.link
                navigate={~p"/owner/analytics"}
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <div class="p-2 bg-blue-100 rounded-lg">
                  <.icon name="hero-chart-bar" class="w-5 h-5 text-blue-600" />
                </div>
                <span class="font-medium text-gray-700">View Analytics</span>
              </.link>
              <.link
                navigate={~p"/owner/settings"}
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <div class="p-2 bg-gray-100 rounded-lg">
                  <.icon name="hero-cog-6-tooth" class="w-5 h-5 text-gray-600" />
                </div>
                <span class="font-medium text-gray-700">Platform Settings</span>
              </.link>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Recent Activity -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100">
        <div class="p-4 border-b border-gray-100">
          <h2 class="text-lg font-semibold text-gray-900">Recent Platform Activity</h2>
        </div>
        <div class="divide-y divide-gray-50">
          <%= if Enum.empty?(@recent_activity) do %>
            <div class="p-8 text-center text-gray-500">
              <.icon name="hero-clock" class="w-12 h-12 mx-auto text-gray-300 mb-3" />
              <p>No recent activity</p>
            </div>
          <% else %>
            <%= for activity <- @recent_activity do %>
              <.activity_row activity={activity} />
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Components

  defp stat_card(assigns) do
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
          <span class={"text-sm font-medium #{if @change >= 0, do: "text-green-600", else: "text-red-600"}"}>
            {if @change >= 0, do: "+", else: ""}{@change}%
          </span>
        <% end %>
      </div>
      <div class="mt-4">
        <p class="text-2xl font-bold text-gray-900">{@value}</p>
        <p class="text-sm text-gray-500 mt-1">{@title}</p>
      </div>
    </div>
    """
  end

  defp user_row(assigns) do
    ~H"""
    <div class="p-4 hover:bg-gray-50 transition-colors">
      <div class="flex items-center gap-4">
        <div class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center">
          <span class="text-purple-600 font-medium">
            {String.first(@user.name || @user.email) |> String.upcase()}
          </span>
        </div>
        <div class="flex-1 min-w-0">
          <p class="font-medium text-gray-900 truncate">{@user.name || "No name"}</p>
          <p class="text-sm text-gray-500 truncate">{@user.email}</p>
        </div>
        <div class="text-right">
          <span class={"px-2 py-1 text-xs rounded-full #{tier_badge(@user.subscription_tier)}"}>
            {String.capitalize(@user.subscription_tier || "free")}
          </span>
          <p class="text-xs text-gray-400 mt-1">
            Joined {format_date(@user.inserted_at)}
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp distribution_bar(assigns) do
    percentage =
      if assigns.total && assigns.total > 0 do
        round(assigns.value / assigns.total * 100)
      else
        0
      end

    color_classes = %{
      "gray" => "bg-gray-400",
      "blue" => "bg-blue-500",
      "purple" => "bg-purple-500",
      "orange" => "bg-orange-500"
    }

    assigns =
      assigns
      |> assign(:percentage, percentage)
      |> assign(:bar_color, Map.get(color_classes, assigns.color, "bg-gray-400"))

    ~H"""
    <div>
      <div class="flex justify-between text-sm mb-1">
        <span class="text-gray-600">{@label}</span>
        <span class="text-gray-900 font-medium">{@value}</span>
      </div>
      <div class="h-2 bg-gray-100 rounded-full overflow-hidden">
        <div class={"h-full rounded-full #{@bar_color}"} style={"width: #{@percentage}%"}></div>
      </div>
    </div>
    """
  end

  defp activity_row(assigns) do
    ~H"""
    <div class="p-4 hover:bg-gray-50 transition-colors">
      <div class="flex items-center gap-4">
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
    </div>
    """
  end

  # Helper Functions

  defp load_platform_stats do
    base_stats = %{
      total_users: 0,
      total_transfers: 0,
      active_shares: 0,
      total_storage: 0,
      users_change: nil,
      transfers_change: nil,
      shares_change: nil,
      storage_change: nil,
      users_by_tier: %{}
    }

    # Try to load actual stats
    user_count =
      case function_exported?(Accounts, :count_users_by_role, 0) do
        true ->
          counts = Accounts.count_users_by_role()
          Map.values(counts) |> Enum.sum()

        false ->
          case function_exported?(Accounts, :list_users, 0) do
            true -> Accounts.list_users() |> length()
            false -> 0
          end
      end

    %{base_stats | total_users: user_count}
  rescue
    _ ->
      %{
        total_users: 0,
        total_transfers: 0,
        active_shares: 0,
        total_storage: 0,
        users_change: nil,
        transfers_change: nil,
        shares_change: nil,
        storage_change: nil,
        users_by_tier: %{}
      }
  end

  defp load_recent_users do
    case function_exported?(Accounts, :list_users, 0) do
      true -> Accounts.list_users() |> Enum.take(5)
      false -> []
    end
  rescue
    _ -> []
  end

  defp load_recent_activity do
    # Return empty list - activity tracking can be implemented later
    []
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

  defp format_date(nil), do: "N/A"
  defp format_date(datetime), do: Calendar.strftime(datetime, "%b %d, %Y")

  defp format_datetime(nil), do: "N/A"
  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")

  defp tier_badge(tier) do
    case tier do
      "enterprise" -> "bg-orange-100 text-orange-700"
      "business" -> "bg-purple-100 text-purple-700"
      "pro" -> "bg-blue-100 text-blue-700"
      _ -> "bg-gray-100 text-gray-700"
    end
  end

  defp activity_icon(type) do
    case type do
      :user_registered -> "hero-user-plus"
      :transfer_completed -> "hero-arrow-up-tray"
      :share_created -> "hero-share"
      _ -> "hero-clock"
    end
  end

  defp activity_icon_bg(type) do
    case type do
      :user_registered -> "bg-purple-50"
      :transfer_completed -> "bg-blue-50"
      :share_created -> "bg-green-50"
      _ -> "bg-gray-50"
    end
  end

  defp activity_icon_color(type) do
    case type do
      :user_registered -> "text-purple-600"
      :transfer_completed -> "text-blue-600"
      :share_created -> "text-green-600"
      _ -> "text-gray-600"
    end
  end
end
