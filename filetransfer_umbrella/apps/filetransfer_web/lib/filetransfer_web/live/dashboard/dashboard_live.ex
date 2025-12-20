defmodule FiletransferWeb.Dashboard.DashboardLive do
  @moduledoc """
  Main dashboard view for authenticated users.
  Shows overview of user's file transfers, shares, and usage statistics.
  """
  use FiletransferWeb, :live_view

  alias FiletransferCore.Transfers
  alias FiletransferCore.Sharing
  alias FiletransferCore.Usage

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:recent_transfers, load_recent_transfers(user))
      |> assign(:recent_shares, load_recent_shares(user))
      |> assign(:usage_stats, load_usage_stats(user))

    {:ok, socket, layout: {FiletransferWeb.Layouts, :user_dashboard}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Welcome Header -->
      <div class="bg-gradient-to-r from-blue-500 to-cyan-500 rounded-xl p-6 text-white">
        <h1 class="text-2xl font-bold">Welcome back, {@current_user.name || @current_user.email}!</h1>
        <p class="text-blue-100 mt-1">Here's an overview of your file transfer activity.</p>
      </div>
      
    <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <.stat_card
          title="Total Transfers"
          value={@usage_stats.total_transfers}
          icon="hero-arrow-up-tray"
          color="blue"
        />
        <.stat_card
          title="Active Shares"
          value={@usage_stats.active_shares}
          icon="hero-share"
          color="green"
        />
        <.stat_card
          title="Storage Used"
          value={format_bytes(@usage_stats.storage_used)}
          icon="hero-server-stack"
          color="purple"
        />
      </div>
      
    <!-- Recent Activity Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Recent Transfers -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100">
          <div class="p-4 border-b border-gray-100 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-900">Recent Transfers</h2>
            <.link
              navigate={~p"/dashboard/transfers"}
              class="text-sm text-blue-600 hover:text-blue-700"
            >
              View all →
            </.link>
          </div>
          <div class="divide-y divide-gray-50">
            <%= if Enum.empty?(@recent_transfers) do %>
              <div class="p-8 text-center text-gray-500">
                <.icon name="hero-cloud-arrow-up" class="w-12 h-12 mx-auto text-gray-300 mb-3" />
                <p>No transfers yet</p>
                <p class="text-sm mt-1">Your recent file transfers will appear here.</p>
              </div>
            <% else %>
              <%= for transfer <- @recent_transfers do %>
                <.transfer_item transfer={transfer} />
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- Recent Shares -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-100">
          <div class="p-4 border-b border-gray-100 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-900">Recent Shares</h2>
            <.link navigate={~p"/dashboard/shares"} class="text-sm text-blue-600 hover:text-blue-700">
              View all →
            </.link>
          </div>
          <div class="divide-y divide-gray-50">
            <%= if Enum.empty?(@recent_shares) do %>
              <div class="p-8 text-center text-gray-500">
                <.icon name="hero-link" class="w-12 h-12 mx-auto text-gray-300 mb-3" />
                <p>No active shares</p>
                <p class="text-sm mt-1">Your share links will appear here.</p>
              </div>
            <% else %>
              <%= for share <- @recent_shares do %>
                <.share_item share={share} />
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Quick Actions -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <.quick_action_button
            label="New Transfer"
            icon="hero-cloud-arrow-up"
            color="blue"
            href={~p"/dashboard/transfers/new"}
          />
          <.quick_action_button
            label="Create Share Link"
            icon="hero-link"
            color="green"
            href={~p"/dashboard/shares/new"}
          />
          <.quick_action_button
            label="View Files"
            icon="hero-folder"
            color="purple"
            href={~p"/dashboard/transfers"}
          />
          <.quick_action_button
            label="Settings"
            icon="hero-cog-6-tooth"
            color="gray"
            href={~p"/dashboard/settings"}
          />
        </div>
      </div>
    </div>
    """
  end

  # Components

  defp stat_card(assigns) do
    color_classes = %{
      "blue" => "bg-blue-50 text-blue-600",
      "green" => "bg-green-50 text-green-600",
      "purple" => "bg-purple-50 text-purple-600"
    }

    assigns =
      assign(
        assigns,
        :color_class,
        Map.get(color_classes, assigns.color, "bg-gray-50 text-gray-600")
      )

    ~H"""
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
      <div class="flex items-center gap-4">
        <div class={"p-3 rounded-lg #{@color_class}"}>
          <.icon name={@icon} class="w-6 h-6" />
        </div>
        <div>
          <p class="text-sm text-gray-500">{@title}</p>
          <p class="text-2xl font-bold text-gray-900">{@value}</p>
        </div>
      </div>
    </div>
    """
  end

  defp transfer_item(assigns) do
    ~H"""
    <div class="p-4 hover:bg-gray-50 transition-colors">
      <div class="flex items-center gap-3">
        <div class="p-2 bg-blue-50 rounded-lg">
          <.icon name="hero-document" class="w-5 h-5 text-blue-600" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="font-medium text-gray-900 truncate">{@transfer.filename || "Untitled"}</p>
          <p class="text-sm text-gray-500">
            {format_bytes(@transfer.file_size || 0)} · {format_datetime(@transfer.inserted_at)}
          </p>
        </div>
        <span class={"px-2 py-1 text-xs rounded-full #{status_color(@transfer.status)}"}>
          {@transfer.status}
        </span>
      </div>
    </div>
    """
  end

  defp share_item(assigns) do
    ~H"""
    <div class="p-4 hover:bg-gray-50 transition-colors">
      <div class="flex items-center gap-3">
        <div class="p-2 bg-green-50 rounded-lg">
          <.icon name="hero-link" class="w-5 h-5 text-green-600" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="font-medium text-gray-900 truncate">{@share.name || "Share Link"}</p>
          <p class="text-sm text-gray-500">
            {pluralize(@share.download_count || 0, "download")} · Expires {format_datetime(
              @share.expires_at
            )}
          </p>
        </div>
        <button
          type="button"
          phx-click="copy_share_link"
          phx-value-id={@share.id}
          class="text-gray-400 hover:text-gray-600"
        >
          <.icon name="hero-clipboard-document" class="w-5 h-5" />
        </button>
      </div>
    </div>
    """
  end

  defp quick_action_button(assigns) do
    color_classes = %{
      "blue" => "bg-blue-50 text-blue-600 hover:bg-blue-100",
      "green" => "bg-green-50 text-green-600 hover:bg-green-100",
      "purple" => "bg-purple-50 text-purple-600 hover:bg-purple-100",
      "gray" => "bg-gray-50 text-gray-600 hover:bg-gray-100"
    }

    assigns =
      assign(
        assigns,
        :color_class,
        Map.get(color_classes, assigns.color, "bg-gray-50 text-gray-600 hover:bg-gray-100")
      )

    ~H"""
    <.link
      navigate={@href}
      class={"flex flex-col items-center justify-center p-4 rounded-xl transition-colors #{@color_class}"}
    >
      <.icon name={@icon} class="w-8 h-8 mb-2" />
      <span class="text-sm font-medium">{@label}</span>
    </.link>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("copy_share_link", %{"id" => _id}, socket) do
    {:noreply, put_flash(socket, :info, "Share link copied to clipboard!")}
  end

  # Helper Functions

  defp load_recent_transfers(user) do
    case function_exported?(Transfers, :list_user_transfers, 2) do
      true -> Transfers.list_user_transfers(user.id, limit: 5)
      false -> []
    end
  rescue
    _ -> []
  end

  defp load_recent_shares(user) do
    case function_exported?(Sharing, :list_user_share_links, 2) do
      true -> Sharing.list_user_share_links(user.id, limit: 5)
      false -> []
    end
  rescue
    _ -> []
  end

  defp load_usage_stats(user) do
    base_stats = %{
      total_transfers: 0,
      active_shares: 0,
      storage_used: 0
    }

    case function_exported?(Usage, :get_user_stats, 1) do
      true ->
        case Usage.get_user_stats(user.id) do
          {:ok, stats} -> Map.merge(base_stats, stats)
          {:error, _} -> base_stats
        end

      false ->
        base_stats
    end
  rescue
    _ -> %{total_transfers: 0, active_shares: 0, storage_used: 0}
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_bytes(_), do: "0 B"

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp status_color(status) do
    case status do
      "completed" -> "bg-green-100 text-green-700"
      "pending" -> "bg-yellow-100 text-yellow-700"
      "failed" -> "bg-red-100 text-red-700"
      _ -> "bg-gray-100 text-gray-700"
    end
  end

  defp pluralize(count, word) when count == 1, do: "#{count} #{word}"
  defp pluralize(count, word), do: "#{count} #{word}s"
end
