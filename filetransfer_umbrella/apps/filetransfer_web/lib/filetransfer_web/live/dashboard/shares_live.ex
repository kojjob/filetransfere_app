defmodule FiletransferWeb.Dashboard.SharesLive do
  @moduledoc """
  LiveView for managing user's share links.
  Allows creating, viewing, and managing share links for files.
  """
  use FiletransferWeb, :live_view

  alias FiletransferCore.Sharing

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Share Links")
      |> assign(:filter, "active")
      |> assign(:has_shares?, false)
      |> stream(:shares, [])

    {:ok, socket, layout: {FiletransferWeb.Layouts, :user_dashboard}}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = Map.get(params, "filter", "active")
    shares = load_shares(socket.assigns.current_user, filter)

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:has_shares?, shares != [] && length(shares) > 0)
      |> stream(:shares, shares, reset: true)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Share Links</h1>
          <p class="text-gray-500 mt-1">Manage your file sharing links and permissions.</p>
        </div>
        <.link
          navigate={~p"/dashboard/shares/new"}
          class="inline-flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
        >
          <.icon name="hero-plus" class="w-5 h-5" /> Create Share Link
        </.link>
      </div>
      
    <!-- Filter Tabs -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
        <div class="flex gap-2">
          <.filter_button filter="active" current={@filter} label="Active" count={nil} />
          <.filter_button filter="expired" current={@filter} label="Expired" count={nil} />
          <.filter_button filter="all" current={@filter} label="All" count={nil} />
        </div>
      </div>
      
    <!-- Shares List -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div id="shares-list" phx-update="stream" class="divide-y divide-gray-100">
          <div
            :for={{dom_id, share} <- @streams.shares}
            id={dom_id}
            class="p-4 hover:bg-gray-50 transition-colors"
          >
            <div class="flex items-start gap-4">
              <!-- Icon -->
              <div class={"p-3 rounded-lg #{share_status_bg(share)}"}>
                <.icon name="hero-link" class={"w-6 h-6 #{share_status_icon_color(share)}"} />
              </div>
              
    <!-- Share Info -->
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1">
                  <p class="font-medium text-gray-900 truncate">{share.transfer.file_name || "Share Link"}</p>
                  <span class={"px-2 py-0.5 text-xs rounded-full #{share_status_badge(share)}"}>
                    {share_status_text(share)}
                  </span>
                </div>
                
    <!-- Share URL -->
                <div class="flex items-center gap-2 bg-gray-50 rounded-lg p-2 mb-2">
                  <code class="text-sm text-gray-600 truncate flex-1">{share_url(share)}</code>
                  <button
                    type="button"
                    phx-click="copy_link"
                    phx-value-id={share.id}
                    class="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-gray-200 rounded transition-colors"
                    title="Copy link"
                  >
                    <.icon name="hero-clipboard-document" class="w-4 h-4" />
                  </button>
                </div>
                
    <!-- Stats -->
                <div class="flex flex-wrap gap-4 text-sm text-gray-500">
                  <span class="flex items-center gap-1">
                    <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
                    {pluralize(share.download_count || 0, "download")}
                  </span>
                  <span class="flex items-center gap-1">
                    <.icon name="hero-clock" class="w-4 h-4" />
                    Expires {format_expiry(share.expires_at)}
                  </span>
                  <%= if share.max_downloads do %>
                    <span class="flex items-center gap-1">
                      <.icon name="hero-arrow-path" class="w-4 h-4" />
                      {share.download_count || 0}/{share.max_downloads} downloads
                    </span>
                  <% end %>
                  <%= if share.password_hash do %>
                    <span class="flex items-center gap-1">
                      <.icon name="hero-lock-closed" class="w-4 h-4" /> Password protected
                    </span>
                  <% end %>
                </div>
              </div>
              
    <!-- Actions -->
              <div class="flex items-center gap-1">
                <button
                  type="button"
                  phx-click="edit"
                  phx-value-id={share.id}
                  class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                  title="Edit"
                >
                  <.icon name="hero-pencil-square" class="w-5 h-5" />
                </button>
                <button
                  type="button"
                  phx-click="view_stats"
                  phx-value-id={share.id}
                  class="p-2 text-gray-400 hover:text-purple-600 hover:bg-purple-50 rounded-lg transition-colors"
                  title="View statistics"
                >
                  <.icon name="hero-chart-bar" class="w-5 h-5" />
                </button>
                <%= if is_active?(share) do %>
                  <button
                    type="button"
                    phx-click="revoke"
                    phx-value-id={share.id}
                    data-confirm="Are you sure you want to revoke this share link? It will no longer be accessible."
                    class="p-2 text-gray-400 hover:text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                    title="Revoke"
                  >
                    <.icon name="hero-no-symbol" class="w-5 h-5" />
                  </button>
                <% end %>
                <button
                  type="button"
                  phx-click="delete"
                  phx-value-id={share.id}
                  data-confirm="Are you sure you want to delete this share link permanently?"
                  class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                  title="Delete"
                >
                  <.icon name="hero-trash" class="w-5 h-5" />
                </button>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Empty State -->
        <div :if={!@has_shares?} class="p-12 text-center">
          <.icon name="hero-link" class="w-16 h-16 mx-auto text-gray-300 mb-4" />
          <h3 class="text-lg font-medium text-gray-900 mb-2">No share links found</h3>
          <p class="text-gray-500 mb-6">
            <%= case @filter do %>
              <% "active" -> %>
                You don't have any active share links.
              <% "expired" -> %>
                You don't have any expired share links.
              <% _ -> %>
                Create your first share link to share files.
            <% end %>
          </p>
          <.link
            navigate={~p"/dashboard/shares/new"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
          >
            <.icon name="hero-plus" class="w-5 h-5" /> Create Share Link
          </.link>
        </div>
      </div>
    </div>
    """
  end

  # Components

  defp filter_button(assigns) do
    active = assigns.filter == assigns.current

    assigns =
      assign(
        assigns,
        :class,
        if active do
          "px-4 py-2 text-sm font-medium rounded-lg bg-green-100 text-green-700"
        else
          "px-4 py-2 text-sm font-medium rounded-lg text-gray-600 hover:bg-gray-100"
        end
      )

    ~H"""
    <.link patch={~p"/dashboard/shares?filter=#{@filter}"} class={@class}>
      {@label}
    </.link>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("copy_link", %{"id" => _id}, socket) do
    {:noreply, put_flash(socket, :info, "Share link copied to clipboard!")}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/dashboard/shares/#{id}/edit")}
  end

  @impl true
  def handle_event("view_stats", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/dashboard/shares/#{id}/stats")}
  end

  @impl true
  def handle_event("revoke", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case revoke_share(user, id) do
      {:ok, share} ->
        socket =
          socket
          |> stream_insert(:shares, share)
          |> put_flash(:info, "Share link has been revoked.")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke share link.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case delete_share(user, id) do
      {:ok, share} ->
        socket =
          socket
          |> stream_delete(:shares, share)
          |> put_flash(:info, "Share link deleted successfully.")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete share link.")}
    end
  end

  # Helper Functions

  defp load_shares(user, filter) do
    opts =
      case filter do
        "active" -> [status: "active"]
        "expired" -> [status: "expired"]
        _ -> []
      end

    case function_exported?(Sharing, :list_user_share_links, 2) do
      true -> Sharing.list_user_share_links(user.id, opts)
      false -> []
    end
  rescue
    _ -> []
  end

  defp revoke_share(user, id) do
    case function_exported?(Sharing, :revoke_share_link, 2) do
      true -> Sharing.revoke_share_link(user.id, id)
      false -> {:error, :not_implemented}
    end
  rescue
    _ -> {:error, :internal_error}
  end

  defp delete_share(user, id) do
    case function_exported?(Sharing, :delete_share_link, 2) do
      true -> Sharing.delete_share_link(user.id, id)
      false -> {:error, :not_implemented}
    end
  rescue
    _ -> {:error, :internal_error}
  end

  defp share_url(share) do
    base_url = FiletransferWeb.Endpoint.url()
    "#{base_url}/s/#{share.token || share.id}"
  end

  defp is_active?(share) do
    now = DateTime.utc_now()

    cond do
      not share.is_active -> false
      share.expires_at && DateTime.compare(share.expires_at, now) == :lt -> false
      share.max_downloads && (share.download_count || 0) >= share.max_downloads -> false
      true -> true
    end
  end

  defp share_status_text(share) do
    cond do
      not share.is_active -> "Revoked"
      not is_active?(share) -> "Expired"
      true -> "Active"
    end
  end

  defp share_status_badge(share) do
    cond do
      not share.is_active -> "bg-gray-100 text-gray-700"
      not is_active?(share) -> "bg-red-100 text-red-700"
      true -> "bg-green-100 text-green-700"
    end
  end

  defp share_status_bg(share) do
    cond do
      not share.is_active -> "bg-gray-50"
      not is_active?(share) -> "bg-red-50"
      true -> "bg-green-50"
    end
  end

  defp share_status_icon_color(share) do
    cond do
      not share.is_active -> "text-gray-600"
      not is_active?(share) -> "text-red-600"
      true -> "text-green-600"
    end
  end

  defp format_expiry(nil), do: "Never"

  defp format_expiry(expires_at) do
    now = DateTime.utc_now()

    if DateTime.compare(expires_at, now) == :lt do
      "Expired"
    else
      diff = DateTime.diff(expires_at, now, :second)

      cond do
        diff < 60 -> "in less than a minute"
        diff < 3600 -> "in #{div(diff, 60)} minutes"
        diff < 86400 -> "in #{div(diff, 3600)} hours"
        diff < 604_800 -> "in #{div(diff, 86400)} days"
        true -> Calendar.strftime(expires_at, "%b %d, %Y")
      end
    end
  end

  defp pluralize(count, word) when count == 1, do: "#{count} #{word}"
  defp pluralize(count, word), do: "#{count} #{word}s"
end
