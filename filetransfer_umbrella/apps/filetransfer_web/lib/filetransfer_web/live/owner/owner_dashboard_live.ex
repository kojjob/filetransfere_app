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
      |> assign(:page_title, "Overview")
      |> assign(:active_tab, "overview")
      |> assign(:platform_stats, load_platform_stats())
      |> assign(:recent_users, load_recent_users())
      |> assign(:recent_activity, load_recent_activity())

    {:ok, socket, layout: {FiletransferWeb.Layouts, :owner_dashboard}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Top Row: Key Metrics --%>
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <.stat_card
          title="Total Users"
          value={@platform_stats.total_users}
          change={@platform_stats.users_change}
          icon="hero-users"
          color="amber"
        />
        <.stat_card
          title="Transfers"
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
          title="Storage"
          value={format_bytes(@platform_stats.total_storage)}
          change={@platform_stats.storage_change}
          icon="hero-server-stack"
          color="coral"
        />
        <.stat_card
          title="Bandwidth"
          value={format_bandwidth(@platform_stats)}
          change={nil}
          icon="hero-signal"
          color="emerald"
        />
        <.stat_card
          title="Success Rate"
          value="99.8%"
          change={nil}
          icon="hero-check-badge"
          color="amber"
        />
      </div>

      <%!-- Second Row: Map + Charts --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- User Location Map --%>
        <div class="lg:col-span-2 obsidian-card rounded-xl overflow-hidden">
          <div class="px-5 py-4 flex items-center justify-between border-b border-[#d4af37]/10 [[data-theme=light]_&]:border-[#8b6914]/10">
            <div class="flex items-center gap-3">
              <div class="obsidian-icon-box">
                <.icon name="hero-globe-alt" class="w-4 h-4 obsidian-accent-amber" />
              </div>
              <h2 class="text-sm font-semibold obsidian-text-primary">User Locations</h2>
            </div>
            <div class="flex items-center gap-4 text-[11px]">
              <span class="flex items-center gap-1.5">
                <span class="w-2 h-2 rounded-full bg-[#d4af37]"></span>
                <span class="obsidian-text-tertiary">Active</span>
              </span>
              <span class="flex items-center gap-1.5">
                <span class="w-2 h-2 rounded-full bg-[#2dd4bf]"></span>
                <span class="obsidian-text-tertiary">New</span>
              </span>
            </div>
          </div>
          <div class="luxe-map-container p-6 h-64 relative">
            <%!-- Simple world map visualization with dots --%>
            <svg viewBox="0 0 800 400" class="w-full h-full opacity-20">
              <path
                d="M150,120 Q200,80 250,100 T350,90 T450,100 T550,85 T650,100"
                fill="none"
                stroke="currentColor"
                stroke-width="1"
                class="obsidian-text-tertiary"
              />
              <path
                d="M100,200 Q180,180 260,195 T400,180 T540,200 T680,190"
                fill="none"
                stroke="currentColor"
                stroke-width="1"
                class="obsidian-text-tertiary"
              />
              <path
                d="M180,280 Q250,260 350,275 T500,260 T620,280"
                fill="none"
                stroke="currentColor"
                stroke-width="1"
                class="obsidian-text-tertiary"
              />
            </svg>
            <%!-- Location dots --%>
            <div class="luxe-map-dot" style="top: 30%; left: 20%;"></div>
            <div class="luxe-map-dot luxe-map-dot-teal" style="top: 35%; left: 48%;"></div>
            <div class="luxe-map-dot" style="top: 40%; left: 75%;"></div>
            <div class="luxe-map-dot luxe-map-dot-teal" style="top: 55%; left: 25%;"></div>
            <div class="luxe-map-dot luxe-map-dot-coral" style="top: 45%; left: 85%;"></div>
            <div class="luxe-map-dot" style="top: 60%; left: 55%;"></div>
            <%!-- Region stats overlay --%>
            <div class="absolute bottom-4 left-4 right-4 flex justify-between">
              <.region_stat
                region="Americas"
                users={@platform_stats.users_by_region["americas"] || 0}
                percentage={45}
              />
              <.region_stat
                region="Europe"
                users={@platform_stats.users_by_region["europe"] || 0}
                percentage={32}
              />
              <.region_stat
                region="Asia Pacific"
                users={@platform_stats.users_by_region["apac"] || 0}
                percentage={23}
              />
            </div>
          </div>
        </div>

        <%!-- File Types Breakdown --%>
        <div class="obsidian-card rounded-xl p-5">
          <div class="flex items-center gap-3 mb-5">
            <div class="obsidian-icon-box">
              <.icon name="hero-document" class="w-4 h-4 obsidian-accent-amber" />
            </div>
            <h3 class="text-sm font-semibold obsidian-text-primary">File Types</h3>
          </div>
          <div class="space-y-4">
            <.file_type_bar label="Documents" icon="hero-document-text" percentage={35} color="amber" />
            <.file_type_bar label="Images" icon="hero-photo" percentage={28} color="emerald" />
            <.file_type_bar label="Videos" icon="hero-film" percentage={20} color="sky" />
            <.file_type_bar label="Archives" icon="hero-archive-box" percentage={12} color="coral" />
            <.file_type_bar label="Other" icon="hero-folder" percentage={5} color="slate" />
          </div>
        </div>
      </div>

      <%!-- Third Row: Users + Distribution + Activity --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Recent Users --%>
        <div class="obsidian-card rounded-xl overflow-hidden">
          <div class="px-5 py-4 flex items-center justify-between border-b border-[#d4af37]/10 [[data-theme=light]_&]:border-[#8b6914]/10">
            <div class="flex items-center gap-3">
              <div class="obsidian-icon-box">
                <.icon name="hero-users" class="w-4 h-4 obsidian-accent-amber" />
              </div>
              <h2 class="text-sm font-semibold obsidian-text-primary">Recent Users</h2>
            </div>
            <.link
              navigate={~p"/owner/users"}
              class="text-xs font-medium obsidian-accent-amber hover:underline"
            >
              View all
            </.link>
          </div>
          <div class="divide-y divide-[#d4af37]/5 [[data-theme=light]_&]:divide-[#8b6914]/5">
            <%= if Enum.empty?(@recent_users) do %>
              <div class="p-8 text-center">
                <div class="obsidian-icon-box mx-auto mb-3 w-10 h-10">
                  <.icon name="hero-users" class="w-5 h-5 obsidian-text-tertiary" />
                </div>
                <p class="text-sm obsidian-text-secondary">No users yet</p>
              </div>
            <% else %>
              <%= for user <- Enum.take(@recent_users, 4) do %>
                <.user_row user={user} />
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- User Tiers & Peak Hours --%>
        <div class="space-y-6">
          <%!-- User Distribution --%>
          <div class="obsidian-card rounded-xl p-5">
            <div class="flex items-center gap-3 mb-4">
              <div class="obsidian-icon-box">
                <.icon name="hero-chart-pie" class="w-4 h-4 obsidian-accent-amber" />
              </div>
              <h3 class="text-sm font-semibold obsidian-text-primary">Subscriptions</h3>
            </div>
            <div class="space-y-3">
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

          <%!-- Peak Hours --%>
          <div class="obsidian-card rounded-xl p-5">
            <div class="flex items-center gap-3 mb-4">
              <div class="obsidian-icon-box">
                <.icon name="hero-clock" class="w-4 h-4 obsidian-accent-emerald" />
              </div>
              <h3 class="text-sm font-semibold obsidian-text-primary">Peak Hours</h3>
            </div>
            <div class="flex items-end justify-between h-16 gap-1">
              <%= for {hour, activity} <- peak_hours_data() do %>
                <div class="flex-1 flex flex-col items-center gap-1">
                  <div
                    class="w-full rounded-t bg-gradient-to-t from-[#d4af37]/60 to-[#d4af37] transition-all"
                    style={"height: #{activity}%"}
                  >
                  </div>
                  <span class="text-[9px] obsidian-text-tertiary">{hour}</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Recent Activity --%>
        <div class="obsidian-card rounded-xl overflow-hidden">
          <div class="px-5 py-4 flex items-center gap-3 border-b border-[#d4af37]/10 [[data-theme=light]_&]:border-[#8b6914]/10">
            <div class="obsidian-icon-box">
              <.icon name="hero-bolt" class="w-4 h-4 obsidian-accent-emerald" />
            </div>
            <h2 class="text-sm font-semibold obsidian-text-primary">Activity</h2>
            <div class="flex items-center gap-1.5 ml-auto">
              <span class="obsidian-live-dot"></span>
              <span class="text-[10px] obsidian-text-tertiary">Live</span>
            </div>
          </div>
          <div class="divide-y divide-[#d4af37]/5 [[data-theme=light]_&]:divide-[#8b6914]/5">
            <%= if Enum.empty?(@recent_activity) do %>
              <div class="p-8 text-center">
                <div class="obsidian-icon-box mx-auto mb-3 w-10 h-10">
                  <.icon name="hero-clock" class="w-5 h-5 obsidian-text-tertiary" />
                </div>
                <p class="text-sm obsidian-text-secondary">No recent activity</p>
              </div>
            <% else %>
              <%= for activity <- @recent_activity do %>
                <.activity_row activity={activity} />
              <% end %>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Bottom Row: Quick Actions --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <.link
          navigate={~p"/owner/users"}
          class="obsidian-card rounded-xl p-5 group hover:border-[#d4af37]/30 transition-all"
        >
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-[#d4af37]/10 flex items-center justify-center group-hover:bg-[#d4af37]/20 transition-colors">
              <.icon name="hero-user-plus" class="w-6 h-6 obsidian-accent-amber" />
            </div>
            <div>
              <h3 class="text-sm font-semibold obsidian-text-primary group-hover:obsidian-accent-amber transition-colors">
                Manage Users
              </h3>
              <p class="text-xs obsidian-text-tertiary">View and manage platform users</p>
            </div>
          </div>
        </.link>
        <.link
          navigate={~p"/owner/analytics"}
          class="obsidian-card rounded-xl p-5 group hover:border-[#2dd4bf]/30 transition-all"
        >
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-[#2dd4bf]/10 flex items-center justify-center group-hover:bg-[#2dd4bf]/20 transition-colors">
              <.icon name="hero-chart-bar" class="w-6 h-6 obsidian-accent-emerald" />
            </div>
            <div>
              <h3 class="text-sm font-semibold obsidian-text-primary group-hover:obsidian-accent-emerald transition-colors">
                Analytics
              </h3>
              <p class="text-xs obsidian-text-tertiary">Detailed platform insights</p>
            </div>
          </div>
        </.link>
        <.link
          navigate={~p"/owner/settings"}
          class="obsidian-card rounded-xl p-5 group hover:border-[#38bdf8]/30 transition-all"
        >
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-[#38bdf8]/10 flex items-center justify-center group-hover:bg-[#38bdf8]/20 transition-colors">
              <.icon name="hero-cog-6-tooth" class="w-6 h-6 obsidian-accent-sky" />
            </div>
            <div>
              <h3 class="text-sm font-semibold obsidian-text-primary group-hover:obsidian-accent-sky transition-colors">
                Settings
              </h3>
              <p class="text-xs obsidian-text-tertiary">Configure platform settings</p>
            </div>
          </div>
        </.link>
      </div>
    </div>
    """
  end

  # Components

  defp region_stat(assigns) do
    ~H"""
    <div class="text-center">
      <p class="text-[10px] obsidian-text-tertiary uppercase tracking-wider">{@region}</p>
      <p class="text-sm font-semibold obsidian-text-primary">{@percentage}%</p>
    </div>
    """
  end

  defp file_type_bar(assigns) do
    bar_colors = %{
      "amber" => "bg-[#d4af37]",
      "emerald" => "bg-[#2dd4bf]",
      "sky" => "bg-[#38bdf8]",
      "coral" => "bg-[#fb923c]",
      "slate" => "bg-[#b4aa9b]"
    }

    assigns = assign(assigns, :bar_color, Map.get(bar_colors, assigns.color, "bg-[#b4aa9b]"))

    ~H"""
    <div class="flex items-center gap-3">
      <div class="w-7 h-7 rounded-lg bg-white/5 [[data-theme=light]_&]:bg-black/5 flex items-center justify-center">
        <.icon name={@icon} class="w-3.5 h-3.5 obsidian-text-secondary" />
      </div>
      <div class="flex-1">
        <div class="flex justify-between mb-1">
          <span class="text-xs obsidian-text-secondary">{@label}</span>
          <span class="text-xs obsidian-text-primary font-medium">{@percentage}%</span>
        </div>
        <div class="h-1.5 bg-white/5 [[data-theme=light]_&]:bg-black/5 rounded-full overflow-hidden">
          <div class={"h-full rounded-full #{@bar_color}"} style={"width: #{@percentage}%"}></div>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
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
          <span class={[
            "obsidian-badge text-[11px]",
            if(@change >= 0,
              do: "obsidian-badge-emerald",
              else: "bg-red-500/15 text-red-400 border border-red-500/20"
            )
          ]}>
            {if @change >= 0, do: "↑", else: "↓"} {abs(@change)}%
          </span>
        <% end %>
      </div>
      <p class="obsidian-stat text-2xl obsidian-text-primary">{@value}</p>
      <p class="text-xs obsidian-text-tertiary mt-1 uppercase tracking-wider">{@title}</p>
    </div>
    """
  end

  defp user_row(assigns) do
    ~H"""
    <div class="obsidian-table-row px-5 py-4">
      <div class="flex items-center gap-4">
        <div class="w-9 h-9 rounded-lg bg-gradient-to-br from-amber-500/20 to-orange-500/10 flex items-center justify-center">
          <span class="text-sm font-semibold obsidian-accent-amber">
            {String.first(@user.name || @user.email) |> String.upcase()}
          </span>
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium obsidian-text-primary truncate">{@user.name || "No name"}</p>
          <p class="text-xs obsidian-text-tertiary truncate">{@user.email}</p>
        </div>
        <div class="text-right flex flex-col items-end gap-1">
          <span class={tier_badge(@user.subscription_tier)}>
            {String.capitalize(@user.subscription_tier || "free")}
          </span>
          <p class="text-[11px] obsidian-text-tertiary">
            {format_date(@user.inserted_at)}
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

    bar_colors = %{
      "slate" => "bg-[#b4aa9b]",
      "sky" => "bg-[#38bdf8]",
      "amber" => "bg-[#d4af37]",
      "emerald" => "bg-[#2dd4bf]"
    }

    assigns =
      assigns
      |> assign(:percentage, percentage)
      |> assign(:bar_color, Map.get(bar_colors, assigns.color, "bg-slate-400"))

    ~H"""
    <div>
      <div class="flex justify-between items-center mb-2">
        <span class="text-xs obsidian-text-secondary">{@label}</span>
        <span class="obsidian-stat text-xs obsidian-text-primary">{@value}</span>
      </div>
      <div class="obsidian-progress">
        <div class={"obsidian-progress-bar #{@bar_color}"} style={"width: #{@percentage}%"}></div>
      </div>
    </div>
    """
  end

  defp activity_row(assigns) do
    ~H"""
    <div class="obsidian-table-row px-5 py-4">
      <div class="flex items-center gap-4">
        <div class={"w-9 h-9 rounded-lg flex items-center justify-center #{activity_icon_bg(@activity.type)}"}>
          <.icon
            name={activity_icon(@activity.type)}
            class={"w-4 h-4 #{activity_icon_color(@activity.type)}"}
          />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm obsidian-text-primary">{@activity.description}</p>
          <p class="text-xs obsidian-text-tertiary mt-0.5">
            {format_datetime(@activity.inserted_at)}
          </p>
        </div>
      </div>
    </div>
    """
  end

  # Helper Functions

  defp peak_hours_data do
    # Returns list of {hour_label, activity_percentage} for peak hours visualization
    [
      {"6am", 15},
      {"9am", 65},
      {"12pm", 85},
      {"3pm", 95},
      {"6pm", 70},
      {"9pm", 45},
      {"12am", 20}
    ]
  end

  defp format_bandwidth(%{total_bandwidth: bandwidth}) when is_integer(bandwidth) do
    format_bytes(bandwidth) <> "/mo"
  end

  defp format_bandwidth(_), do: "0 B/mo"

  defp load_platform_stats do
    base_stats = %{
      total_users: 0,
      total_transfers: 0,
      active_shares: 0,
      total_storage: 0,
      total_bandwidth: 0,
      users_change: nil,
      transfers_change: nil,
      shares_change: nil,
      storage_change: nil,
      users_by_tier: %{},
      users_by_region: %{"americas" => 0, "europe" => 0, "apac" => 0}
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
        total_bandwidth: 0,
        users_change: nil,
        transfers_change: nil,
        shares_change: nil,
        storage_change: nil,
        users_by_tier: %{},
        users_by_region: %{"americas" => 0, "europe" => 0, "apac" => 0}
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
      "enterprise" -> "obsidian-badge obsidian-badge-emerald"
      "business" -> "obsidian-badge obsidian-badge-amber"
      "pro" -> "obsidian-badge obsidian-badge-sky"
      _ -> "obsidian-badge obsidian-badge-slate"
    end
  end

  defp activity_icon(type) do
    case type do
      :user_registered -> "hero-user-plus"
      :transfer_completed -> "hero-arrow-up-tray"
      :share_created -> "hero-link"
      _ -> "hero-clock"
    end
  end

  defp activity_icon_bg(type) do
    case type do
      :user_registered -> "bg-[#d4af37]/10"
      :transfer_completed -> "bg-[#2dd4bf]/10"
      :share_created -> "bg-[#38bdf8]/10"
      _ -> "bg-white/5 [[data-theme=light]_&]:bg-black/5"
    end
  end

  defp activity_icon_color(type) do
    case type do
      :user_registered -> "obsidian-accent-amber"
      :transfer_completed -> "obsidian-accent-emerald"
      :share_created -> "obsidian-accent-sky"
      _ -> "obsidian-text-secondary"
    end
  end
end
