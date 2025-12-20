defmodule FiletransferWeb.Dashboard.TransfersLive do
  @moduledoc """
  LiveView for managing user's file transfers.
  Allows viewing, uploading, and managing file transfers.
  """
  use FiletransferWeb, :live_view

  alias FiletransferCore.Transfers

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    transfers = load_transfers(user, "all")

    socket =
      socket
      |> assign(:page_title, "My Transfers")
      |> assign(:filter, "all")
      |> assign(:search, "")
      |> assign(:has_transfers?, transfers != [] && length(transfers) > 0)
      |> stream(:transfers, transfers)

    {:ok, socket, layout: {FiletransferWeb.Layouts, :user_dashboard}}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = Map.get(params, "filter", "all")
    search = Map.get(params, "search", "")
    transfers = load_transfers(socket.assigns.current_user, filter, search)

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:search, search)
      |> assign(:has_transfers?, transfers != [] && length(transfers) > 0)
      |> stream(:transfers, transfers, reset: true)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">My Transfers</h1>
          <p class="text-gray-500 mt-1">Manage your file transfers and uploads.</p>
        </div>
        <.link
          navigate={~p"/dashboard/transfers/new"}
          class="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
        >
          <.icon name="hero-plus" class="w-5 h-5" /> New Transfer
        </.link>
      </div>
      
    <!-- Filters and Search -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
        <div class="flex flex-col sm:flex-row gap-4">
          <!-- Search -->
          <form phx-submit="search" class="flex-1">
            <div class="relative">
              <.icon
                name="hero-magnifying-glass"
                class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400"
              />
              <input
                type="text"
                name="search"
                value={@search}
                placeholder="Search transfers..."
                class="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </form>
          
    <!-- Filter Tabs -->
          <div class="flex gap-2">
            <.filter_button filter="all" current={@filter} label="All" />
            <.filter_button filter="completed" current={@filter} label="Completed" />
            <.filter_button filter="pending" current={@filter} label="Pending" />
            <.filter_button filter="failed" current={@filter} label="Failed" />
          </div>
        </div>
      </div>
      
    <!-- Transfers List -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div id="transfers-list" phx-update="stream" class="divide-y divide-gray-100">
          <div
            :for={{dom_id, transfer} <- @streams.transfers}
            id={dom_id}
            class="p-4 hover:bg-gray-50 transition-colors"
          >
            <div class="flex items-center gap-4">
              <!-- File Icon -->
              <div class={"p-3 rounded-lg #{file_type_bg(transfer)}"}>
                <.icon name={file_type_icon(transfer)} class={"w-6 h-6 #{file_type_color(transfer)}"} />
              </div>
              
    <!-- File Info -->
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <p class="font-medium text-gray-900 truncate">{transfer.filename || "Untitled"}</p>
                  <span class={"px-2 py-0.5 text-xs rounded-full #{status_badge(transfer.status)}"}>
                    {transfer.status}
                  </span>
                </div>
                <p class="text-sm text-gray-500 mt-1">
                  {format_bytes(transfer.file_size || 0)} · Uploaded {format_datetime(
                    transfer.inserted_at
                  )}
                </p>
              </div>
              
    <!-- Actions -->
              <div class="flex items-center gap-2">
                <button
                  type="button"
                  phx-click="download"
                  phx-value-id={transfer.id}
                  class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                  title="Download"
                >
                  <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
                </button>
                <button
                  type="button"
                  phx-click="share"
                  phx-value-id={transfer.id}
                  class="p-2 text-gray-400 hover:text-green-600 hover:bg-green-50 rounded-lg transition-colors"
                  title="Create share link"
                >
                  <.icon name="hero-share" class="w-5 h-5" />
                </button>
                <button
                  type="button"
                  phx-click="delete"
                  phx-value-id={transfer.id}
                  data-confirm="Are you sure you want to delete this transfer?"
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
        <div :if={!@has_transfers?} class="p-12 text-center">
          <.icon name="hero-cloud-arrow-up" class="w-16 h-16 mx-auto text-gray-300 mb-4" />
          <h3 class="text-lg font-medium text-gray-900 mb-2">No transfers found</h3>
          <p class="text-gray-500 mb-6">
            <%= if @filter != "all" or @search != "" do %>
              Try adjusting your filters or search query.
            <% else %>
              Upload your first file to get started.
            <% end %>
          </p>
          <.link
            navigate={~p"/dashboard/transfers/new"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            <.icon name="hero-plus" class="w-5 h-5" /> Upload File
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
          "px-4 py-2 text-sm font-medium rounded-lg bg-blue-100 text-blue-700"
        else
          "px-4 py-2 text-sm font-medium rounded-lg text-gray-600 hover:bg-gray-100"
        end
      )

    ~H"""
    <.link patch={~p"/dashboard/transfers?filter=#{@filter}"} class={@class}>
      {@label}
    </.link>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/dashboard/transfers?filter=#{socket.assigns.filter}&search=#{search}"
     )}
  end

  @impl true
  def handle_event("download", %{"id" => id}, socket) do
    # TODO: Implement download functionality
    {:noreply, put_flash(socket, :info, "Preparing download for transfer #{id}...")}
  end

  @impl true
  def handle_event("share", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/dashboard/shares/new?transfer_id=#{id}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case delete_transfer(user, id) do
      {:ok, transfer} ->
        socket =
          socket
          |> stream_delete(:transfers, transfer)
          |> put_flash(:info, "Transfer deleted successfully.")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete transfer.")}
    end
  end

  # Helper Functions

  defp load_transfers(user, filter, search \\ "") do
    opts = [filter: filter]
    opts = if search != "", do: Keyword.put(opts, :search, search), else: opts

    case function_exported?(Transfers, :list_user_transfers, 2) do
      true -> Transfers.list_user_transfers(user.id, opts)
      false -> []
    end
  rescue
    _ -> []
  end

  defp delete_transfer(user, id) do
    case function_exported?(Transfers, :delete_user_transfer, 2) do
      true -> Transfers.delete_user_transfer(user.id, id)
      false -> {:error, :not_implemented}
    end
  rescue
    _ -> {:error, :internal_error}
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
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp status_badge(status) do
    case status do
      "completed" -> "bg-green-100 text-green-700"
      "pending" -> "bg-yellow-100 text-yellow-700"
      "failed" -> "bg-red-100 text-red-700"
      "processing" -> "bg-blue-100 text-blue-700"
      _ -> "bg-gray-100 text-gray-700"
    end
  end

  defp file_type_icon(transfer) do
    extension = get_file_extension(transfer.filename)

    case extension do
      ext when ext in ~w(jpg jpeg png gif webp svg) -> "hero-photo"
      ext when ext in ~w(mp4 mov avi mkv) -> "hero-film"
      ext when ext in ~w(mp3 wav flac aac) -> "hero-musical-note"
      ext when ext in ~w(pdf) -> "hero-document-text"
      ext when ext in ~w(zip rar 7z tar gz) -> "hero-archive-box"
      ext when ext in ~w(doc docx txt md) -> "hero-document"
      ext when ext in ~w(xls xlsx csv) -> "hero-table-cells"
      _ -> "hero-document"
    end
  end

  defp file_type_bg(transfer) do
    extension = get_file_extension(transfer.filename)

    case extension do
      ext when ext in ~w(jpg jpeg png gif webp svg) -> "bg-pink-50"
      ext when ext in ~w(mp4 mov avi mkv) -> "bg-purple-50"
      ext when ext in ~w(mp3 wav flac aac) -> "bg-orange-50"
      ext when ext in ~w(pdf) -> "bg-red-50"
      ext when ext in ~w(zip rar 7z tar gz) -> "bg-yellow-50"
      _ -> "bg-blue-50"
    end
  end

  defp file_type_color(transfer) do
    extension = get_file_extension(transfer.filename)

    case extension do
      ext when ext in ~w(jpg jpeg png gif webp svg) -> "text-pink-600"
      ext when ext in ~w(mp4 mov avi mkv) -> "text-purple-600"
      ext when ext in ~w(mp3 wav flac aac) -> "text-orange-600"
      ext when ext in ~w(pdf) -> "text-red-600"
      ext when ext in ~w(zip rar 7z tar gz) -> "text-yellow-600"
      _ -> "text-blue-600"
    end
  end

  defp get_file_extension(nil), do: ""

  defp get_file_extension(filename) do
    filename
    |> Path.extname()
    |> String.downcase()
    |> String.trim_leading(".")
  end
end
