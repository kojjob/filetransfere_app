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
      <%!-- Platform Stats --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <.stat_card
          title="Total Users"
          value={@platform_stats.total_users}
          change={@platform_stats.users_change}
          icon="hero-users"
          color="amber"
        />
        <.stat_card
          title="Total Transfers"
          value={@platform_stats.total_transfers}
          change={@platform_stats.transfers_change}
          icon="hero-arrow-up-tray"
          color="emerald"
        />
        <.stat_card
          title="Active Shares"
          value={@platform_stats.active_shares}
          change={@platform_stats.shares_change}
          icon="hero-link"
          color="sky"
        />
        <.stat_card
          title="Storage Used"
          value={format_bytes(@platform_stats.total_storage)}
          change={@platform_stats.storage_change}
          icon="hero-server-stack"
          color="coral"
        />
      </div>

      <%!-- Main Content Grid --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Recent Users --%>
        <div class="lg:col-span-2 obsidian-card rounded-xl overflow-hidden">
          <div class="px-5 py-4 flex items-center justify-between border-b border-white/5 [[data-theme=light]_&]:border-black/5">
            <div class="flex items-center gap-3">
              <div class="obsidian-icon-box">
                <.icon name="hero-users" class="w-4 h-4 obsidian-text-secondary" />
              </div>
              <h2 class="text-sm font-semibold obsidian-text-primary">Recent Users</h2>
            </div>
            <.link navigate={~p"/owner/users"} class="text-xs font-medium obsidian-accent-amber hover:underline">
              View all
            </.link>
          </div>
          <div class="divide-y divide-white/5 [[data-theme=light]_&]:divide-black/5">
            <%= if Enum.empty?(@recent_users) do %>
              <div class="p-10 text-center">
                <div class="obsidian-icon-box mx-auto mb-3 w-12 h-12">
                  <.icon name="hero-users" class="w-6 h-6 obsidian-text-tertiary" />
                </div>
                <p class="text-sm obsidian-text-secondary">No users yet</p>
                <p class="text-xs obsidian-text-tertiary mt-1">Users will appear here once they register</p>
              </div>
            <% else %>
              <%= for user <- @recent_users do %>
                <.user_row user={user} />
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- Right Column --%>
        <div class="space-y-6">
          <%!-- User Distribution --%>
          <div class="obsidian-card rounded-xl p-5">
            <div class="flex items-center gap-3 mb-5">
              <div class="obsidian-icon-box">
                <.icon name="hero-chart-pie" class="w-4 h-4 obsidian-text-secondary" />
              </div>
              <h3 class="text-sm font-semibold obsidian-text-primary">User Tiers</h3>
            </div>
            <div class="space-y-4">
              <.distribution_bar
                label="Free"
                value={@platform_stats.users_by_tier["free"] || 0}
                total={@platform_stats.total_users}
                color="slate"
              />
              <.distribution_bar
                label="Pro"
                value={@platform_stats.users_by_tier["pro"] || 0}
                total={@platform_stats.total_users}
                color="sky"
              />
              <.distribution_bar
                label="Business"
                value={@platform_stats.users_by_tier["business"] || 0}
                total={@platform_stats.total_users}
                color="amber"
              />
              <.distribution_bar
                label="Enterprise"
                value={@platform_stats.users_by_tier["enterprise"] || 0}
                total={@platform_stats.total_users}
                color="emerald"
              />
            </div>
          </div>

          <%!-- Quick Actions --%>
          <div class="obsidian-card rounded-xl p-5">
            <div class="flex items-center gap-3 mb-4">
              <div class="obsidian-icon-box">
                <.icon name="hero-bolt" class="w-4 h-4 obsidian-text-secondary" />
              </div>
              <h3 class="text-sm font-semibold obsidian-text-primary">Quick Actions</h3>
            </div>
            <div class="space-y-2">
              <.link
                navigate={~p"/owner/users"}
                class="flex items-center gap-3 p-3 rounded-lg transition-colors hover:bg-white/5 [[data-theme=light]_&]:hover:bg-black/5 group"
              >
                <div class="w-8 h-8 rounded-lg bg-amber-500/10 flex items-center justify-center group-hover:bg-amber-500/20 transition-colors">
                  <.icon name="hero-user-plus" class="w-4 h-4 obsidian-accent-amber" />
                </div>
                <span class="text-sm font-medium obsidian-text-secondary group-hover:obsidian-text-primary transition-colors">Manage Users</span>
              </.link>
              <.link
                navigate={~p"/owner/analytics"}
                class="flex items-center gap-3 p-3 rounded-lg transition-colors hover:bg-white/5 [[data-theme=light]_&]:hover:bg-black/5 group"
              >
                <div class="w-8 h-8 rounded-lg bg-sky-500/10 flex items-center justify-center group-hover:bg-sky-500/20 transition-colors">
                  <.icon name="hero-chart-bar" class="w-4 h-4 obsidian-accent-sky" />
                </div>
                <span class="text-sm font-medium obsidian-text-secondary group-hover:obsidian-text-primary transition-colors">View Analytics</span>
              </.link>
              <.link
                navigate={~p"/owner/settings"}
                class="flex items-center gap-3 p-3 rounded-lg transition-colors hover:bg-white/5 [[data-theme=light]_&]:hover:bg-black/5 group"
              >
                <div class="w-8 h-8 rounded-lg bg-white/5 [[data-theme=light]_&]:bg-black/5 flex items-center justify-center group-hover:bg-white/10 [[data-theme=light]_&]:group-hover:bg-black/10 transition-colors">
                  <.icon name="hero-cog-6-tooth" class="w-4 h-4 obsidian-text-secondary" />
                </div>
                <span class="text-sm font-medium obsidian-text-secondary group-hover:obsidian-text-primary transition-colors">Platform Settings</span>
              </.link>
            </div>
          </div>
        </div>
      </div>

      <%!-- Recent Activity --%>
      <div class="obsidian-card rounded-xl overflow-hidden">
        <div class="px-5 py-4 flex items-center gap-3 border-b border-white/5 [[data-theme=light]_&]:border-black/5">
          <div class="obsidian-icon-box">
            <.icon name="hero-clock" class="w-4 h-4 obsidian-text-secondary" />
          </div>
          <h2 class="text-sm font-semibold obsidian-text-primary">Recent Activity</h2>
          <div class="flex items-center gap-1.5 ml-auto">
            <span class="obsidian-live-dot"></span>
            <span class="text-[11px] obsidian-text-tertiary">Live</span>
          </div>
        </div>
        <div class="divide-y divide-white/5 [[data-theme=light]_&]:divide-black/5">
          <%= if Enum.empty?(@recent_activity) do %>
            <div class="p-10 text-center">
              <div class="obsidian-icon-box mx-auto mb-3 w-12 h-12">
                <.icon name="hero-clock" class="w-6 h-6 obsidian-text-tertiary" />
              </div>
              <p class="text-sm obsidian-text-secondary">No recent activity</p>
              <p class="text-xs obsidian-text-tertiary mt-1">Activity will appear here as users interact with the platform</p>
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
