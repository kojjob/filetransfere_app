defmodule FiletransferWeb.DashboardLive do
  @moduledoc """
  Main dashboard with working dropdowns, notifications, and user menu.
  """
  use FiletransferWeb, :live_view

  alias FiletransferCore.Transfers
  alias FiletransferCore.Sharing

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:current_tab, :dashboard)
      |> assign(:sidebar_collapsed, false)
      |> assign(:selected_file, nil)
      |> assign(:file_shares, [])
      |> assign(:show_upload_modal, false)
      |> assign(:show_user_menu, false)
      |> assign(:show_notifications, false)
      |> assign(:upload_progress, %{})
      |> assign(:search_query, "")
      |> assign(:theme, "dark")
      |> assign(:notifications, sample_notifications())
      |> assign_current_user(session)
      |> allow_upload(:files,
        accept: :any,
        max_entries: 10,
        max_file_size: 10_000_000_000,
        progress: &handle_progress/3,
        auto_upload: false
      )

    if connected?(socket) && socket.assigns[:current_user] do
      Phoenix.PubSub.subscribe(FiletransferCore.PubSub, "user:#{socket.assigns.current_user.id}")
    end

    {:ok, load_dashboard_data(socket)}
  end

  defp sample_notifications do
    [
      %{
        id: 1,
        type: :upload,
        title: "Upload Complete",
        message: "report.pdf uploaded successfully",
        time: "2 min ago",
        read: false
      },
      %{
        id: 2,
        type: :share,
        title: "New Download",
        message: "Someone downloaded your shared file",
        time: "1 hour ago",
        read: false
      },
      %{
        id: 3,
        type: :system,
        title: "Storage Alert",
        message: "You're using 75% of your storage",
        time: "Yesterday",
        read: true
      }
    ]
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = String.to_existing_atom(params["tab"] || "dashboard")
    {:noreply, assign(socket, :current_tab, tab)}
  rescue
    ArgumentError -> {:noreply, assign(socket, :current_tab, :dashboard)}
  end

  defp assign_current_user(socket, session) do
    case session["user_id"] do
      nil ->
        assign(socket, :current_user, nil)

      user_id ->
        case FiletransferCore.Accounts.get_user(user_id) do
          {:ok, user} -> assign(socket, :current_user, user)
          _ -> assign(socket, :current_user, nil)
        end
    end
  end

  defp load_dashboard_data(socket) do
    user = socket.assigns[:current_user]

    if user do
      socket
      |> assign(:stats, calculate_stats(user))
      |> assign(:recent_transfers, get_recent_transfers(user))
      |> assign(:active_shares, get_active_shares(user))
      |> assign(:storage_breakdown, calculate_storage_breakdown(user))
      |> assign(:recent_activity, get_recent_activity(user))
    else
      socket
      |> assign(:stats, default_stats())
      |> assign(:recent_transfers, [])
      |> assign(:active_shares, [])
      |> assign(:storage_breakdown, [])
      |> assign(:recent_activity, [])
    end
  end

  defp calculate_stats(user) do
    transfers = Transfers.list_transfers(user.id) |> elem(1)

    shares =
      case Sharing.list_user_share_links(user.id) do
        {:ok, list} -> list
        _ -> []
      end

    today = Date.utc_today()

    uploads_today =
      Enum.count(transfers, fn t ->
        Date.compare(DateTime.to_date(t.inserted_at), today) == :eq
      end)

    total_size = Enum.reduce(transfers, 0, fn t, acc -> acc + (t.file_size || 0) end)
    completed = Enum.count(transfers, &(&1.status == "completed"))

    %{
      uploads_today: uploads_today,
      total_uploads: length(transfers),
      active_shares: length(shares),
      downloads_total: Enum.reduce(shares, 0, fn s, acc -> acc + (s.download_count || 0) end),
      storage_used: total_size,
      storage_limit: 10_000_000_000,
      completed_transfers: completed,
      pending_transfers: length(transfers) - completed
    }
  end

  defp default_stats do
    %{
      uploads_today: 0,
      total_uploads: 0,
      active_shares: 0,
      downloads_total: 0,
      storage_used: 0,
      storage_limit: 10_000_000_000,
      completed_transfers: 0,
      pending_transfers: 0
    }
  end

  defp get_recent_transfers(user) do
    case Transfers.list_transfers(user.id) do
      {:ok, transfers} -> Enum.take(transfers, 10)
      _ -> []
    end
  end

  defp get_active_shares(user) do
    case Sharing.list_user_share_links(user.id) do
      {:ok, shares} -> Enum.filter(shares, & &1.is_active) |> Enum.take(5)
      _ -> []
    end
  end

  defp get_file_shares(transfer_id, user_id) do
    case Sharing.list_user_share_links(user_id) do
      {:ok, shares} -> Enum.filter(shares, &(&1.transfer_id == transfer_id))
      _ -> []
    end
  end

  defp calculate_storage_breakdown(user) do
    transfers =
      case Transfers.list_transfers(user.id) do
        {:ok, list} -> list
        _ -> []
      end

    transfers
    |> Enum.group_by(&get_file_category/1)
    |> Enum.map(fn {category, files} ->
      %{
        category: category,
        count: length(files),
        size: Enum.reduce(files, 0, fn f, acc -> acc + (f.file_size || 0) end),
        color: category_color(category)
      }
    end)
    |> Enum.sort_by(& &1.size, :desc)
  end

  defp get_file_category(transfer) do
    ext = Path.extname(transfer.file_name || "") |> String.downcase()

    cond do
      ext in ~w(.jpg .jpeg .png .gif .webp .svg .bmp .ico) ->
        :images

      ext in ~w(.mp4 .mov .avi .mkv .webm .flv .wmv) ->
        :videos

      ext in ~w(.mp3 .wav .flac .aac .ogg .wma .m4a) ->
        :audio

      ext in ~w(.pdf .doc .docx .xls .xlsx .ppt .pptx .txt .rtf .odt) ->
        :documents

      ext in ~w(.zip .rar .7z .tar .gz .bz2) ->
        :archives

      ext in ~w(.js .ts .py .rb .ex .exs .go .rs .java .c .cpp .h .css .html .json .xml .yml .yaml) ->
        :code

      true ->
        :other
    end
  end

  defp category_color(:images), do: "from-pink-500 to-rose-500"
  defp category_color(:videos), do: "from-purple-500 to-violet-500"
  defp category_color(:audio), do: "from-green-500 to-emerald-500"
  defp category_color(:documents), do: "from-blue-500 to-cyan-500"
  defp category_color(:archives), do: "from-orange-500 to-amber-500"
  defp category_color(:code), do: "from-indigo-500 to-blue-500"
  defp category_color(:other), do: "from-slate-500 to-gray-500"

  defp get_recent_activity(user) do
    get_recent_transfers(user)
    |> Enum.take(8)
    |> Enum.map(fn t ->
      %{
        id: t.id,
        type: :upload,
        file_name: t.file_name,
        file_size: t.file_size,
        status: t.status,
        timestamp: t.inserted_at,
        icon: file_icon(t.file_name)
      }
    end)
  end

  defp file_icon(filename) do
    ext = Path.extname(filename || "") |> String.downcase()

    cond do
      ext in ~w(.jpg .jpeg .png .gif .webp .svg) -> "hero-photo"
      ext in ~w(.mp4 .mov .avi .mkv .webm) -> "hero-film"
      ext in ~w(.mp3 .wav .flac .aac) -> "hero-musical-note"
      ext in ~w(.pdf) -> "hero-document-text"
      ext in ~w(.doc .docx .txt .rtf) -> "hero-document"
      ext in ~w(.xls .xlsx) -> "hero-table-cells"
      ext in ~w(.ppt .pptx) -> "hero-presentation-chart-bar"
      ext in ~w(.zip .rar .7z .tar .gz) -> "hero-archive-box"
      ext in ~w(.js .ts .py .rb .ex .go .rs .java .c .cpp .css .html) -> "hero-code-bracket"
      true -> "hero-document"
    end
  end

  defp handle_progress(:files, entry, socket) do
    progress = Map.put(socket.assigns.upload_progress, entry.ref, entry.progress)
    {:noreply, assign(socket, :upload_progress, progress)}
  end

  defp get_mime_type(filename) do
    ext = Path.extname(filename || "") |> String.downcase() |> String.trim_leading(".")

    mime_types = %{
      "jpg" => "image/jpeg",
      "jpeg" => "image/jpeg",
      "png" => "image/png",
      "gif" => "image/gif",
      "webp" => "image/webp",
      "svg" => "image/svg+xml",
      "mp4" => "video/mp4",
      "mov" => "video/quicktime",
      "mp3" => "audio/mpeg",
      "wav" => "audio/wav",
      "pdf" => "application/pdf",
      "doc" => "application/msword",
      "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "xls" => "application/vnd.ms-excel",
      "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "txt" => "text/plain",
      "html" => "text/html",
      "css" => "text/css",
      "js" => "application/javascript",
      "json" => "application/json",
      "zip" => "application/zip"
    }

    Map.get(mime_types, ext, "application/octet-stream")
  end

  # Event Handlers
  @impl true
  def handle_event("toggle_theme", _, socket) do
    new_theme = if socket.assigns.theme == "dark", do: "light", else: "dark"
    {:noreply, assign(socket, :theme, new_theme)}
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  @impl true
  def handle_event("toggle_user_menu", _, socket) do
    {:noreply,
     socket
     |> assign(:show_user_menu, !socket.assigns.show_user_menu)
     |> assign(:show_notifications, false)}
  end

  @impl true
  def handle_event("toggle_notifications", _, socket) do
    {:noreply,
     socket
     |> assign(:show_notifications, !socket.assigns.show_notifications)
     |> assign(:show_user_menu, false)}
  end

  @impl true
  def handle_event("close_dropdowns", _, socket) do
    {:noreply, socket |> assign(:show_user_menu, false) |> assign(:show_notifications, false)}
  end

  @impl true
  def handle_event("mark_notification_read", %{"id" => id}, socket) do
    id = String.to_integer(id)

    notifications =
      Enum.map(socket.assigns.notifications, fn n ->
        if n.id == id, do: %{n | read: true}, else: n
      end)

    {:noreply, assign(socket, :notifications, notifications)}
  end

  @impl true
  def handle_event("mark_all_read", _, socket) do
    notifications = Enum.map(socket.assigns.notifications, &%{&1 | read: true})
    {:noreply, assign(socket, :notifications, notifications)}
  end

  @impl true
  def handle_event("clear_notifications", _, socket) do
    {:noreply, assign(socket, :notifications, [])}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/dashboard?tab=#{tab}")}
  end

  @impl true
  def handle_event("show_upload_modal", _, socket) do
    {:noreply, assign(socket, :show_upload_modal, true)}
  end

  @impl true
  def handle_event("close_upload_modal", _, socket) do
    {:noreply, assign(socket, :show_upload_modal, false)}
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  @impl true
  def handle_event("start_upload", _params, socket) do
    {:noreply, put_flash(socket, :info, "Upload started!")}
  end

  @impl true
  def handle_event("select_file", %{"id" => id}, socket) do
    transfer = Enum.find(socket.assigns.recent_transfers, &(&1.id == id))

    file_shares =
      if transfer && socket.assigns.current_user do
        get_file_shares(id, socket.assigns.current_user.id)
      else
        []
      end

    {:noreply, socket |> assign(:selected_file, transfer) |> assign(:file_shares, file_shares)}
  end

  @impl true
  def handle_event("close_preview", _, socket) do
    {:noreply, socket |> assign(:selected_file, nil) |> assign(:file_shares, [])}
  end

  @impl true
  def handle_event("copy_share_link", %{"token" => _token}, socket) do
    {:noreply, put_flash(socket, :info, "Link copied to clipboard!")}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  @impl true
  def handle_event("delete_transfer", %{"id" => id}, socket) do
    case Transfers.delete_transfer(id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "File deleted")
         |> assign(:selected_file, nil)
         |> load_dashboard_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete file")}
    end
  end

  @impl true
  def handle_event("create_share_link", %{"id" => id}, socket) do
    case Sharing.create_share_link(socket.assigns.current_user.id, id) do
      {:ok, _share} ->
        file_shares = get_file_shares(id, socket.assigns.current_user.id)

        {:noreply,
         socket
         |> put_flash(:info, "Share link created!")
         |> assign(:file_shares, file_shares)
         |> load_dashboard_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create share link")}
    end
  end

  # Theme classes helper
  defp tc(theme) do
    if theme == "light" do
      %{
        bg: "bg-gray-50",
        sidebar: "bg-white border-gray-200",
        card: "bg-white border-gray-200",
        text: "text-gray-900",
        muted: "text-gray-500",
        subtle: "text-gray-400",
        input: "bg-gray-100 border-gray-200",
        hover: "hover:bg-gray-100",
        border: "border-gray-200",
        header: "bg-white/80",
        kbd: "bg-gray-200",
        progress: "bg-gray-200",
        row: "bg-gray-50",
        divider: "bg-gray-200",
        dropdown: "bg-white border-gray-200 shadow-lg"
      }
    else
      %{
        bg: "bg-slate-900",
        sidebar: "bg-slate-800/95 border-slate-700/50",
        card: "bg-slate-800/50 border-slate-700/50",
        text: "text-white",
        muted: "text-slate-400",
        subtle: "text-slate-500",
        input: "bg-slate-800/50 border-slate-700/50",
        hover: "hover:bg-slate-700/50",
        border: "border-slate-700/50",
        header: "bg-slate-900/80",
        kbd: "bg-slate-700/50",
        progress: "bg-slate-700",
        row: "bg-slate-700/30",
        divider: "bg-slate-700",
        dropdown: "bg-slate-800 border-slate-700 shadow-xl"
      }
    end
  end

  @impl true
  def render(assigns) do
    t = tc(assigns.theme)
    unread_count = Enum.count(assigns.notifications, &(!&1.read))
    assigns = assigns |> assign(:t, t) |> assign(:unread_count, unread_count)

    ~H"""
    <div
      class={"min-h-screen flex transition-colors duration-300 #{@t.bg}"}
      phx-click="close_dropdowns"
    >
      <!-- Sidebar -->
      <aside class={[
        "fixed inset-y-0 left-0 z-50 flex flex-col backdrop-blur-xl border-r transition-all duration-300",
        @t.sidebar,
        @sidebar_collapsed && "w-20",
        !@sidebar_collapsed && "w-72"
      ]}>
        <div class={"h-16 flex items-center justify-between px-4 border-b #{@t.border}"}>
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-cyan-400 to-blue-500 flex items-center justify-center">
              <.icon name="hero-bolt" class="w-6 h-6 text-white" />
            </div>
            <span class={[
              "font-bold text-xl transition-opacity",
              @t.text,
              @sidebar_collapsed && "opacity-0 w-0 overflow-hidden"
            ]}>
              ZipShare
            </span>
          </div>
          <button phx-click="toggle_sidebar" class={"p-2 rounded-lg #{@t.hover} #{@t.muted}"}>
            <.icon
              name={if @sidebar_collapsed, do: "hero-chevron-right", else: "hero-chevron-left"}
              class="w-5 h-5"
            />
          </button>
        </div>

        <nav class="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
          <.nav_btn
            icon="hero-squares-2x2"
            label="Dashboard"
            tab={:dashboard}
            current={@current_tab}
            collapsed={@sidebar_collapsed}
            theme={@theme}
          />
          <.nav_btn
            icon="hero-cloud-arrow-up"
            label="Upload"
            tab={:upload}
            current={@current_tab}
            collapsed={@sidebar_collapsed}
            theme={@theme}
          />
          <.nav_btn
            icon="hero-folder"
            label="My Files"
            tab={:files}
            current={@current_tab}
            collapsed={@sidebar_collapsed}
            theme={@theme}
            badge={@stats.total_uploads}
          />
          <.nav_btn
            icon="hero-link"
            label="Shared Links"
            tab={:shares}
            current={@current_tab}
            collapsed={@sidebar_collapsed}
            theme={@theme}
            badge={@stats.active_shares}
          />
          <.nav_btn
            icon="hero-clock"
            label="Recent"
            tab={:recent}
            current={@current_tab}
            collapsed={@sidebar_collapsed}
            theme={@theme}
          />
          <.nav_btn
            icon="hero-star"
            label="Favorites"
            tab={:favorites}
            current={@current_tab}
            collapsed={@sidebar_collapsed}
            theme={@theme}
          />
          <.nav_btn
            icon="hero-trash"
            label="Deleted"
            tab={:deleted}
            current={@current_tab}
            collapsed={@sidebar_collapsed}
            theme={@theme}
          />
          <div class={"pt-4 mt-4 border-t #{@t.border}"}>
            <.nav_btn
              icon="hero-cog-6-tooth"
              label="Settings"
              tab={:settings}
              current={@current_tab}
              collapsed={@sidebar_collapsed}
              theme={@theme}
            />
          </div>
        </nav>

        <div class={["px-4 py-4 border-t", @t.border, @sidebar_collapsed && "px-2"]}>
          <div class={[
            "mb-2 flex items-center justify-between",
            @sidebar_collapsed && "justify-center"
          ]}>
            <span class={["text-sm", @t.muted, @sidebar_collapsed && "hidden"]}>Storage</span>
            <span class={["text-sm font-medium", @t.text, @sidebar_collapsed && "hidden"]}>
              {fmt_storage(@stats.storage_used)} / {fmt_storage(@stats.storage_limit)}
            </span>
          </div>
          <div class={"h-2 rounded-full overflow-hidden #{@t.progress}"}>
            <div
              class="h-full bg-gradient-to-r from-cyan-400 to-blue-500 rounded-full"
              style={"width: #{min(100, (@stats.storage_used / max(@stats.storage_limit, 1)) * 100)}%"}
            />
          </div>
          <button class={[
            "mt-3 w-full py-2 px-3 rounded-lg bg-gradient-to-r from-cyan-500 to-blue-500 text-white text-sm font-medium hover:from-cyan-600 hover:to-blue-600",
            @sidebar_collapsed && "px-2"
          ]}>
            <span class={[@sidebar_collapsed && "hidden"]}>Upgrade</span>
            <.icon :if={@sidebar_collapsed} name="hero-arrow-up" class="w-4 h-4 mx-auto" />
          </button>
        </div>
      </aside>
      
    <!-- Main -->
      <main class={[
        "flex-1 transition-all duration-300",
        @sidebar_collapsed && "ml-20",
        !@sidebar_collapsed && "ml-72",
        @selected_file && "mr-96"
      ]}>
        <header class={[
          "sticky top-0 z-40 h-16 backdrop-blur-xl border-b flex items-center justify-between px-6",
          @t.header,
          @t.border
        ]}>
          <div class="flex items-center gap-4">
            <div class="relative">
              <.icon
                name="hero-magnifying-glass"
                class={"absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 #{@t.muted}"}
              />
              <input
                type="text"
                placeholder="Search files..."
                phx-change="search"
                name="query"
                value={@search_query}
                class={"w-80 pl-10 pr-4 py-2 border rounded-xl focus:outline-none focus:ring-2 focus:ring-cyan-500/50 #{@t.text} #{@t.input}"}
              />
              <kbd class={"absolute right-3 top-1/2 -translate-y-1/2 px-2 py-0.5 text-xs rounded #{@t.muted} #{@t.kbd}"}>
                ⌘K
              </kbd>
            </div>
          </div>

          <div class="flex items-center gap-3">
            <!-- Theme Toggle -->
            <button
              phx-click="toggle_theme"
              class={"p-2 rounded-xl #{@t.hover} #{@t.muted}"}
              title={if @theme == "dark", do: "Light mode", else: "Dark mode"}
            >
              <.icon name={if @theme == "dark", do: "hero-sun", else: "hero-moon"} class="w-5 h-5" />
            </button>
            
    <!-- Upload Button -->
            <button
              phx-click="show_upload_modal"
              class="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-cyan-500 to-blue-500 text-white font-medium rounded-xl hover:from-cyan-600 hover:to-blue-600 shadow-lg shadow-cyan-500/25"
            >
              <.icon name="hero-cloud-arrow-up" class="w-5 h-5" /> Upload
            </button>
            
    <!-- Notifications Dropdown -->
            <div class="relative" phx-click-away="close_dropdowns">
              <button
                phx-click="toggle_notifications"
                class={"p-2 rounded-xl #{@t.hover} #{@t.muted} relative"}
              >
                <.icon name="hero-bell" class="w-5 h-5" />
                <span
                  :if={@unread_count > 0}
                  class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center font-medium"
                >
                  {@unread_count}
                </span>
              </button>
              
    <!-- Notifications Panel -->
              <div
                :if={@show_notifications}
                class={[
                  "absolute right-0 top-full mt-2 w-80 rounded-xl border overflow-hidden z-50",
                  @t.dropdown
                ]}
                phx-click="noop"
              >
                <div class={"p-4 border-b flex items-center justify-between #{@t.border}"}>
                  <h3 class={"font-semibold #{@t.text}"}>Notifications</h3>
                  <div class="flex items-center gap-2">
                    <button
                      :if={@unread_count > 0}
                      phx-click="mark_all_read"
                      class="text-xs text-cyan-500 hover:text-cyan-400"
                    >
                      Mark all read
                    </button>
                    <button
                      :if={length(@notifications) > 0}
                      phx-click="clear_notifications"
                      class={"text-xs #{@t.muted} hover:text-red-400"}
                    >
                      Clear
                    </button>
                  </div>
                </div>
                <div class="max-h-80 overflow-y-auto">
                  <%= for notification <- @notifications do %>
                    <div
                      phx-click="mark_notification_read"
                      phx-value-id={notification.id}
                      class={[
                        "p-4 cursor-pointer transition-colors #{@t.hover}",
                        !notification.read &&
                          if(@theme == "light", do: "bg-cyan-50", else: "bg-cyan-500/10")
                      ]}
                    >
                      <div class="flex items-start gap-3">
                        <div class={[
                          "w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0",
                          notification.type == :upload && "bg-green-500/20 text-green-500",
                          notification.type == :share && "bg-blue-500/20 text-blue-500",
                          notification.type == :system && "bg-orange-500/20 text-orange-500"
                        ]}>
                          <.icon name={notification_icon(notification.type)} class="w-4 h-4" />
                        </div>
                        <div class="flex-1 min-w-0">
                          <p class={"font-medium text-sm #{@t.text}"}>{notification.title}</p>
                          <p class={"text-xs #{@t.muted} truncate"}>{notification.message}</p>
                          <p class={"text-xs #{@t.subtle} mt-1"}>{notification.time}</p>
                        </div>
                        <div
                          :if={!notification.read}
                          class="w-2 h-2 bg-cyan-500 rounded-full flex-shrink-0 mt-2"
                        >
                        </div>
                      </div>
                    </div>
                  <% end %>
                  <div :if={Enum.empty?(@notifications)} class="p-8 text-center">
                    <.icon name="hero-bell-slash" class={"w-10 h-10 mx-auto mb-2 #{@t.subtle}"} />
                    <p class={"text-sm #{@t.muted}"}>No notifications</p>
                  </div>
                </div>
                <div class={"p-3 border-t text-center #{@t.border}"}>
                  <button class="text-sm text-cyan-500 hover:text-cyan-400">
                    View all notifications
                  </button>
                </div>
              </div>
            </div>
            
    <!-- User Menu Dropdown -->
            <div class="relative" phx-click-away="close_dropdowns">
              <button
                phx-click="toggle_user_menu"
                class="flex items-center gap-2 p-1 rounded-xl hover:bg-slate-700/30 transition-colors"
              >
                <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white font-medium">
                  {if @current_user, do: String.first(@current_user.email || "U"), else: "U"}
                </div>
                <.icon
                  name="hero-chevron-down"
                  class={"w-4 h-4 #{@t.muted} transition-transform #{@show_user_menu && "rotate-180"}"}
                />
              </button>
              
    <!-- User Menu Panel -->
              <div
                :if={@show_user_menu}
                class={[
                  "absolute right-0 top-full mt-2 w-64 rounded-xl border overflow-hidden z-50",
                  @t.dropdown
                ]}
                phx-click="noop"
              >
                <div class={"p-4 border-b #{@t.border}"}>
                  <div class="flex items-center gap-3">
                    <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-lg font-medium">
                      {if @current_user, do: String.first(@current_user.email || "U"), else: "U"}
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class={"font-medium truncate #{@t.text}"}>
                        {if @current_user,
                          do: @current_user.name || @current_user.email,
                          else: "Guest User"}
                      </p>
                      <p class={"text-sm truncate #{@t.muted}"}>
                        {if @current_user, do: @current_user.email, else: "Not logged in"}
                      </p>
                    </div>
                  </div>
                </div>

                <div class="p-2">
                  <button
                    phx-click="switch_tab"
                    phx-value-tab="settings"
                    class={"w-full flex items-center gap-3 px-3 py-2 rounded-lg #{@t.hover} #{@t.text}"}
                  >
                    <.icon name="hero-user-circle" class="w-5 h-5" />
                    <span>My Profile</span>
                  </button>
                  <button
                    phx-click="switch_tab"
                    phx-value-tab="settings"
                    class={"w-full flex items-center gap-3 px-3 py-2 rounded-lg #{@t.hover} #{@t.text}"}
                  >
                    <.icon name="hero-cog-6-tooth" class="w-5 h-5" />
                    <span>Settings</span>
                  </button>
                  <button class={"w-full flex items-center gap-3 px-3 py-2 rounded-lg #{@t.hover} #{@t.text}"}>
                    <.icon name="hero-credit-card" class="w-5 h-5" />
                    <span>Billing</span>
                  </button>
                  <button class={"w-full flex items-center gap-3 px-3 py-2 rounded-lg #{@t.hover} #{@t.text}"}>
                    <.icon name="hero-question-mark-circle" class="w-5 h-5" />
                    <span>Help & Support</span>
                  </button>
                </div>

                <div class={"p-2 border-t #{@t.border}"}>
                  <form action="/session" method="post" class="w-full">
                    <input type="hidden" name="_method" value="delete" />
                    <input
                      type="hidden"
                      name="_csrf_token"
                      value={Plug.CSRFProtection.get_csrf_token()}
                    />
                    <button
                      type="submit"
                      class="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-red-500/10 text-red-500"
                    >
                      <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
                      <span>Sign Out</span>
                    </button>
                  </form>
                </div>
              </div>
            </div>
          </div>
        </header>

        <div class="p-6">
          <%= case @current_tab do %>
            <% :dashboard -> %>
              <.dashboard_tab
                stats={@stats}
                transfers={@recent_transfers}
                shares={@active_shares}
                breakdown={@storage_breakdown}
                t={@t}
                theme={@theme}
              />
            <% :upload -> %>
              <.upload_tab uploads={@uploads} progress={@upload_progress} t={@t} theme={@theme} />
            <% :files -> %>
              <.files_tab
                transfers={@recent_transfers}
                selected={@selected_file}
                t={@t}
                theme={@theme}
              />
            <% :shares -> %>
              <.shares_tab shares={@active_shares} t={@t} theme={@theme} />
            <% :recent -> %>
              <.recent_tab activity={@recent_activity} t={@t} theme={@theme} />
            <% :settings -> %>
              <.settings_tab current_user={@current_user} t={@t} theme={@theme} />
            <% _ -> %>
              <.coming_soon tab={@current_tab} t={@t} />
          <% end %>
        </div>
      </main>
      
    <!-- Enhanced File Preview Panel -->
      <aside
        :if={@selected_file}
        class={[
          "fixed inset-y-0 right-0 w-96 backdrop-blur-xl border-l z-50 overflow-y-auto",
          @t.sidebar
        ]}
      >
        <.file_preview file={@selected_file} shares={@file_shares} t={@t} theme={@theme} />
      </aside>

      <.upload_modal
        :if={@show_upload_modal}
        uploads={@uploads}
        progress={@upload_progress}
        t={@t}
        theme={@theme}
      />
    </div>
    """
  end

  defp notification_icon(:upload), do: "hero-cloud-arrow-up"
  defp notification_icon(:share), do: "hero-arrow-down-tray"
  defp notification_icon(:system), do: "hero-exclamation-triangle"
  defp notification_icon(_), do: "hero-bell"

  # Navigation button component
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :tab, :atom, required: true
  attr :current, :atom, required: true
  attr :collapsed, :boolean, default: false
  attr :badge, :integer, default: nil
  attr :theme, :string, default: "dark"

  defp nav_btn(assigns) do
    active =
      if assigns.theme == "light",
        do: "bg-cyan-50 text-cyan-600",
        else: "bg-gradient-to-r from-cyan-500/20 to-blue-500/20 text-white"

    inactive =
      if assigns.theme == "light",
        do: "text-gray-600 hover:text-gray-900 hover:bg-gray-100",
        else: "text-slate-400 hover:text-white hover:bg-slate-700/50"

    assigns = assigns |> assign(:active, active) |> assign(:inactive, inactive)

    ~H"""
    <button
      phx-click="switch_tab"
      phx-value-tab={@tab}
      class={[
        "w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all",
        @current == @tab && @active,
        @current != @tab && @inactive
      ]}
    >
      <.icon name={@icon} class="w-5 h-5 flex-shrink-0" />
      <span class={["flex-1 text-left", @collapsed && "hidden"]}>{@label}</span>
      <span
        :if={@badge && @badge > 0 && !@collapsed}
        class="px-2 py-0.5 text-xs bg-cyan-500/20 text-cyan-400 rounded-full"
      >
        {@badge}
      </span>
    </button>
    """
  end

  # Dashboard tab
  attr :stats, :map, required: true
  attr :transfers, :list, required: true
  attr :shares, :list, required: true
  attr :breakdown, :list, required: true
  attr :t, :map, required: true
  attr :theme, :string, required: true

  defp dashboard_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <.stat_card
          title="Uploads Today"
          value={@stats.uploads_today}
          icon="hero-cloud-arrow-up"
          color="cyan"
          trend="+12%"
          t={@t}
          theme={@theme}
        />
        <.stat_card
          title="Active Shares"
          value={@stats.active_shares}
          icon="hero-link"
          color="purple"
          t={@t}
          theme={@theme}
        />
        <.stat_card
          title="Downloads"
          value={@stats.downloads_total}
          icon="hero-arrow-down-tray"
          color="green"
          trend="+8%"
          t={@t}
          theme={@theme}
        />
        <.stat_card
          title="Storage Used"
          value={fmt_storage(@stats.storage_used)}
          icon="hero-server"
          color="orange"
          sub={"of #{fmt_storage(@stats.storage_limit)}"}
          t={@t}
          theme={@theme}
        />
      </div>

      <div class="grid lg:grid-cols-3 gap-6">
        <div class={["lg:col-span-2 rounded-2xl border overflow-hidden", @t.card]}>
          <div class={"px-6 py-4 border-b flex items-center justify-between #{@t.border}"}>
            <h2 class={"text-lg font-semibold #{@t.text}"}>Recent Files</h2>
            <button
              phx-click="switch_tab"
              phx-value-tab="files"
              class="text-sm text-cyan-400 hover:text-cyan-300"
            >
              See all
            </button>
          </div>
          <div class={"divide-y #{@t.border}"}>
            <%= for transfer <- Enum.take(@transfers, 5) do %>
              <div
                phx-click="select_file"
                phx-value-id={transfer.id}
                class={"px-6 py-4 flex items-center gap-4 cursor-pointer #{@t.hover}"}
              >
                <div class={"w-12 h-12 rounded-xl flex items-center justify-center #{file_bg(transfer.file_name)}"}>
                  <.icon name={file_icon(transfer.file_name)} class="w-6 h-6 text-white" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class={"font-medium truncate #{@t.text}"}>{transfer.file_name}</p>
                  <p class={"text-sm #{@t.muted}"}>{fmt_size(transfer.file_size)}</p>
                </div>
                <div class="text-right">
                  <.status_badge status={transfer.status} />
                  <p class={"text-xs mt-1 #{@t.subtle}"}>{fmt_date(transfer.inserted_at)}</p>
                </div>
              </div>
            <% end %>
            <div :if={Enum.empty?(@transfers)} class="px-6 py-12 text-center">
              <.icon name="hero-folder-open" class={"w-12 h-12 mx-auto mb-3 #{@t.subtle}"} />
              <p class={@t.muted}>No files uploaded yet</p>
              <button
                phx-click="switch_tab"
                phx-value-tab="upload"
                class="mt-3 text-sm text-cyan-400 hover:text-cyan-300"
              >
                Upload your first file
              </button>
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div
            class={"rounded-2xl border border-dashed p-6 text-center cursor-pointer hover:border-cyan-500/50 #{@t.card}"}
            phx-click="switch_tab"
            phx-value-tab="upload"
          >
            <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center">
              <.icon name="hero-cloud-arrow-up" class="w-8 h-8 text-cyan-400" />
            </div>
            <p class={"font-medium mb-1 #{@t.text}"}>Drag & drop files</p>
            <p class={"text-sm #{@t.muted}"}>or click to upload</p>
          </div>

          <div class={["rounded-2xl border p-6", @t.card]}>
            <h3 class={"text-lg font-semibold mb-4 #{@t.text}"}>Storage Breakdown</h3>
            <div class="space-y-3">
              <%= for cat <- @breakdown do %>
                <div class="flex items-center gap-3">
                  <div class={"w-3 h-3 rounded-full bg-gradient-to-r #{cat.color}"}></div>
                  <span class={"flex-1 text-sm capitalize #{@t.muted}"}>{cat.category}</span>
                  <span class={"text-sm #{@t.muted}"}>{cat.count}</span>
                  <span class={"text-sm font-medium #{@t.text}"}>{fmt_size(cat.size)}</span>
                </div>
              <% end %>
              <div :if={Enum.empty?(@breakdown)} class="text-center py-4">
                <p class={"text-sm #{@t.muted}"}>No storage data</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Upload tab
  attr :uploads, :any, required: true
  attr :progress, :map, required: true
  attr :t, :map, required: true
  attr :theme, :string, required: true

  defp upload_tab(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-6">
      <div class="text-center mb-8">
        <h1 class={"text-3xl font-bold mb-2 #{@t.text}"}>Upload Files</h1>
        <p class={@t.muted}>Share large files with anyone. Fast, secure, and simple.</p>
      </div>

      <form phx-change="validate" phx-submit="start_upload">
        <div
          class={[
            "border-2 border-dashed rounded-3xl p-12 text-center hover:border-cyan-500/50 transition-all",
            @t.card
          ]}
          phx-drop-target={@uploads.files.ref}
        >
          <div class="w-24 h-24 mx-auto mb-6 rounded-3xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center">
            <.icon name="hero-cloud-arrow-up" class="w-12 h-12 text-cyan-400" />
          </div>
          <h2 class={"text-2xl font-semibold mb-2 #{@t.text}"}>Drag & drop your files here</h2>
          <p class={"mb-6 #{@t.muted}"}>or click to browse from your computer</p>
          <label class="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-cyan-500 to-blue-500 hover:from-cyan-600 hover:to-blue-600 text-white font-semibold rounded-xl cursor-pointer shadow-lg shadow-cyan-500/25">
            <.icon name="hero-folder-open" class="w-5 h-5" /> Choose Files
            <.live_file_input upload={@uploads.files} class="hidden" />
          </label>
          <p class={"mt-6 text-sm #{@t.subtle}"}>
            Maximum file size: 10GB • All file types supported
          </p>
        </div>

        <%= if Enum.any?(@uploads.files.entries) do %>
          <div class="mt-8 space-y-3">
            <%= for entry <- @uploads.files.entries do %>
              <div class={["p-4 rounded-xl border flex items-center gap-4", @t.card]}>
                <div class={"w-12 h-12 rounded-xl flex items-center justify-center #{file_bg(entry.client_name)}"}>
                  <.icon name={file_icon(entry.client_name)} class="w-6 h-6 text-white" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class={"font-medium truncate #{@t.text}"}>{entry.client_name}</p>
                  <p class={"text-sm #{@t.muted}"}>{fmt_size(entry.client_size)}</p>
                </div>
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  class={"p-2 rounded-lg hover:bg-red-500/10 hover:text-red-400 #{@t.muted}"}
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>
            <% end %>
            <button
              type="submit"
              class="w-full mt-4 py-4 px-6 bg-gradient-to-r from-cyan-500 to-blue-500 hover:from-cyan-600 hover:to-blue-600 text-white font-semibold rounded-xl shadow-lg shadow-cyan-500/25 flex items-center justify-center gap-2"
            >
              <.icon name="hero-rocket-launch" class="w-5 h-5" /> Upload & Get Share Link
            </button>
          </div>
        <% end %>
      </form>
    </div>
    """
  end

  # Settings tab
  attr :current_user, :map, required: true
  attr :t, :map, required: true
  attr :theme, :string, required: true

  defp settings_tab(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-6">
      <h1 class={"text-2xl font-bold #{@t.text}"}>Settings</h1>
      
    <!-- Profile Section -->
      <div class={["rounded-2xl border p-6", @t.card]}>
        <h2 class={"text-lg font-semibold mb-4 #{@t.text}"}>Profile</h2>
        <div class="flex items-start gap-6">
          <div class="w-20 h-20 rounded-2xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-2xl font-bold">
            {if @current_user, do: String.first(@current_user.email || "U"), else: "U"}
          </div>
          <div class="flex-1 space-y-4">
            <div>
              <label class={"text-sm font-medium #{@t.muted}"}>Email</label>
              <p class={"mt-1 #{@t.text}"}>
                {if @current_user, do: @current_user.email, else: "Not logged in"}
              </p>
            </div>
            <div>
              <label class={"text-sm font-medium #{@t.muted}"}>Name</label>
              <p class={"mt-1 #{@t.text}"}>
                {if @current_user && @current_user.name, do: @current_user.name, else: "Not set"}
              </p>
            </div>
            <button class="px-4 py-2 bg-cyan-500 text-white rounded-lg hover:bg-cyan-600">
              Edit Profile
            </button>
          </div>
        </div>
      </div>
      
    <!-- Preferences Section -->
      <div class={["rounded-2xl border p-6", @t.card]}>
        <h2 class={"text-lg font-semibold mb-4 #{@t.text}"}>Preferences</h2>
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <div>
              <p class={"font-medium #{@t.text}"}>Dark Mode</p>
              <p class={"text-sm #{@t.muted}"}>Use dark theme across the app</p>
            </div>
            <button
              phx-click="toggle_theme"
              class={[
                "w-12 h-6 rounded-full transition-colors",
                @theme == "dark" && "bg-cyan-500",
                @theme == "light" && "bg-gray-300"
              ]}
            >
              <div class={[
                "w-5 h-5 rounded-full bg-white shadow transition-transform",
                @theme == "dark" && "translate-x-6",
                @theme == "light" && "translate-x-0.5"
              ]}>
              </div>
            </button>
          </div>
          <div class={"border-t #{@t.border}"}></div>
          <div class="flex items-center justify-between">
            <div>
              <p class={"font-medium #{@t.text}"}>Email Notifications</p>
              <p class={"text-sm #{@t.muted}"}>Receive updates about your files</p>
            </div>
            <button class="w-12 h-6 rounded-full bg-cyan-500">
              <div class="w-5 h-5 rounded-full bg-white shadow translate-x-6"></div>
            </button>
          </div>
        </div>
      </div>
      
    <!-- Danger Zone -->
      <div class="rounded-2xl border border-red-500/30 p-6 bg-red-500/5">
        <h2 class="text-lg font-semibold mb-4 text-red-500">Danger Zone</h2>
        <p class={"mb-4 #{@t.muted}"}>
          Once you delete your account, there is no going back. Please be certain.
        </p>
        <button class="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600">
          Delete Account
        </button>
      </div>
    </div>
    """
  end

  # Stat card
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true
  attr :trend, :string, default: nil
  attr :sub, :string, default: nil
  attr :t, :map, required: true
  attr :theme, :string, required: true

  defp stat_card(assigns) do
    colors = %{
      "cyan" =>
        if(assigns.theme == "light",
          do: "from-cyan-50 to-cyan-50/50 border-cyan-200",
          else: "from-cyan-500/20 to-cyan-500/5 border-cyan-500/20"
        ),
      "purple" =>
        if(assigns.theme == "light",
          do: "from-purple-50 to-purple-50/50 border-purple-200",
          else: "from-purple-500/20 to-purple-500/5 border-purple-500/20"
        ),
      "green" =>
        if(assigns.theme == "light",
          do: "from-green-50 to-green-50/50 border-green-200",
          else: "from-green-500/20 to-green-500/5 border-green-500/20"
        ),
      "orange" =>
        if(assigns.theme == "light",
          do: "from-orange-50 to-orange-50/50 border-orange-200",
          else: "from-orange-500/20 to-orange-500/5 border-orange-500/20"
        )
    }

    icons = %{
      "cyan" => "text-cyan-500",
      "purple" => "text-purple-500",
      "green" => "text-green-500",
      "orange" => "text-orange-500"
    }

    assigns = assigns |> assign(:bg, colors[assigns.color]) |> assign(:ic, icons[assigns.color])

    ~H"""
    <div class={"p-5 rounded-2xl bg-gradient-to-br border #{@bg}"}>
      <div class="flex items-start justify-between">
        <div>
          <p class={"text-sm mb-1 #{@t.muted}"}>{@title}</p>
          <p class={"text-3xl font-bold #{@t.text}"}>{@value}</p>
          <p :if={@sub} class={"text-xs mt-1 #{@t.subtle}"}>{@sub}</p>
          <p :if={@trend} class="text-xs text-green-500 mt-1">
            <.icon name="hero-arrow-trending-up" class="w-3 h-3 inline" /> {@trend}
          </p>
        </div>
        <div class={[
          "p-3 rounded-xl",
          if(@theme == "light", do: "bg-white shadow-sm", else: "bg-slate-800/50"),
          @ic
        ]}>
          <.icon name={@icon} class="w-6 h-6" />
        </div>
      </div>
    </div>
    """
  end

  # Status badge
  attr :status, :string, required: true

  defp status_badge(assigns) do
    {bg, txt} =
      case assigns.status do
        "completed" -> {"bg-green-500/20", "text-green-500"}
        "uploading" -> {"bg-cyan-500/20", "text-cyan-500"}
        "pending" -> {"bg-yellow-500/20", "text-yellow-500"}
        "failed" -> {"bg-red-500/20", "text-red-500"}
        _ -> {"bg-slate-500/20", "text-slate-500"}
      end

    assigns = assign(assigns, :bg, bg) |> assign(:txt, txt)

    ~H"""
    <span class={"px-2 py-0.5 text-xs rounded-full capitalize #{@bg} #{@txt}"}>{@status}</span>
    """
  end

  # Files tab
  attr :transfers, :list, required: true
  attr :selected, :any, required: true
  attr :t, :map, required: true
  attr :theme, :string, required: true

  defp files_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class={"text-2xl font-bold #{@t.text}"}>My Files</h1>
          <p class={"mt-1 #{@t.muted}"}>{length(@transfers)} files • Click any file to see details</p>
        </div>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
        <%= for tr <- @transfers do %>
          <div
            phx-click="select_file"
            phx-value-id={tr.id}
            class={[
              "p-4 rounded-2xl border cursor-pointer hover:border-cyan-500/50 transition-all",
              @t.card,
              @selected && @selected.id == tr.id && "ring-2 ring-cyan-500"
            ]}
          >
            <div class={"w-full aspect-square rounded-xl flex items-center justify-center mb-3 #{file_bg(tr.file_name)}"}>
              <.icon name={file_icon(tr.file_name)} class="w-10 h-10 text-white" />
            </div>
            <p class={"font-medium truncate text-sm #{@t.text}"}>{tr.file_name}</p>
            <p class={"text-xs mt-1 #{@t.muted}"}>{fmt_size(tr.file_size)}</p>
          </div>
        <% end %>
      </div>
      <div :if={Enum.empty?(@transfers)} class="text-center py-20">
        <.icon name="hero-folder-open" class={"w-16 h-16 mx-auto mb-4 #{@t.subtle}"} />
        <p class={"text-lg #{@t.muted}"}>No files yet</p>
        <button
          phx-click="switch_tab"
          phx-value-tab="upload"
          class="mt-4 text-cyan-500 hover:text-cyan-400"
        >
          Upload your first file →
        </button>
      </div>
    </div>
    """
  end

  # Shares tab
  attr :shares, :list, required: true
  attr :t, :map, required: true
  attr :theme, :string, required: true

  defp shares_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <h1 class={"text-2xl font-bold #{@t.text}"}>Shared Links</h1>
      <div class={["rounded-2xl border overflow-hidden", @t.card]}>
        <table class="w-full">
          <thead class={@t.row}>
            <tr>
              <th class={"px-6 py-3 text-left text-xs font-medium uppercase #{@t.muted}"}>File</th>
              <th class={"px-6 py-3 text-left text-xs font-medium uppercase #{@t.muted}"}>Link</th>
              <th class={"px-6 py-3 text-left text-xs font-medium uppercase #{@t.muted}"}>
                Downloads
              </th>
              <th class={"px-6 py-3 text-left text-xs font-medium uppercase #{@t.muted}"}>Expires</th>
            </tr>
          </thead>
          <tbody class={"divide-y #{@t.border}"}>
            <%= for s <- @shares do %>
              <tr class={@t.hover}>
                <td class="px-6 py-4">
                  <div class="flex items-center gap-3">
                    <div class={"w-10 h-10 rounded-lg flex items-center justify-center #{file_bg(s.transfer && s.transfer.file_name)}"}>
                      <.icon
                        name={file_icon(s.transfer && s.transfer.file_name)}
                        class="w-5 h-5 text-white"
                      />
                    </div>
                    <span class={"truncate max-w-[200px] #{@t.text}"}>
                      {if s.transfer, do: s.transfer.file_name, else: "Unknown"}
                    </span>
                  </div>
                </td>
                <td class="px-6 py-4">
                  <code class="text-sm text-cyan-500 bg-cyan-500/10 px-2 py-1 rounded">
                    /s/{s.token}
                  </code>
                </td>
                <td class={"px-6 py-4 #{@t.text}"}>{s.download_count || 0}</td>
                <td class={"px-6 py-4 #{@t.muted}"}>
                  {if s.expires_at, do: fmt_rel(s.expires_at), else: "Never"}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <div :if={Enum.empty?(@shares)} class="px-6 py-12 text-center">
          <.icon name="hero-link" class={"w-12 h-12 mx-auto mb-3 #{@t.subtle}"} />
          <p class={@t.muted}>No shared links yet</p>
        </div>
      </div>
    </div>
    """
  end

  # Recent tab
  attr :activity, :list, required: true
  attr :t, :map, required: true
  attr :theme, :string, required: true

  defp recent_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <h1 class={"text-2xl font-bold #{@t.text}"}>Recent Activity</h1>
      <div class={["rounded-2xl border divide-y", @t.card, @t.border]}>
        <%= for a <- @activity do %>
          <div class={"px-6 py-4 flex items-center gap-4 #{@t.hover}"}>
            <div class={"w-10 h-10 rounded-xl flex items-center justify-center #{file_bg(a.file_name)}"}>
              <.icon name={a.icon} class="w-5 h-5 text-white" />
            </div>
            <div class="flex-1">
              <p class={"font-medium #{@t.text}"}>{a.file_name}</p>
              <p class={"text-sm #{@t.muted}"}>{act_desc(a.type, a.status)}</p>
            </div>
            <div class="text-right">
              <.status_badge status={a.status} />
              <p class={"text-xs mt-1 #{@t.subtle}"}>{fmt_date(a.timestamp)}</p>
            </div>
          </div>
        <% end %>
        <div :if={Enum.empty?(@activity)} class="px-6 py-12 text-center">
          <.icon name="hero-clock" class={"w-12 h-12 mx-auto mb-3 #{@t.subtle}"} />
          <p class={@t.muted}>No recent activity</p>
        </div>
      </div>
    </div>
    """
  end

  # Coming soon
  attr :tab, :atom, required: true
  attr :t, :map, required: true

  defp coming_soon(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-20">
      <div class="w-20 h-20 rounded-2xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center mb-6">
        <.icon name="hero-rocket-launch" class="w-10 h-10 text-cyan-400" />
      </div>
      <h2 class={"text-2xl font-bold mb-2 capitalize #{@t.text}"}>{@tab}</h2>
      <p class={@t.muted}>Coming soon!</p>
    </div>
    """
  end

  # File preview panel
  attr :file, :map, required: true
  attr :shares, :list, required: true
  attr :t, :map, required: true
  attr :theme, :string, required: true

  defp file_preview(assigns) do
    ext =
      Path.extname(assigns.file.file_name || "") |> String.trim_leading(".") |> String.upcase()

    mime = get_mime_type(assigns.file.file_name)
    category = get_file_category(assigns.file)

    total_downloads =
      Enum.reduce(assigns.shares, 0, fn s, acc -> acc + (s.download_count || 0) end)

    assigns =
      assigns
      |> assign(:ext, ext)
      |> assign(:mime, mime)
      |> assign(:category, category)
      |> assign(:total_downloads, total_downloads)

    ~H"""
    <div class="h-full flex flex-col">
      <div class={"p-4 border-b flex items-center justify-between #{@t.border}"}>
        <h3 class={"text-lg font-semibold #{@t.text}"}>File Details</h3>
        <button phx-click="close_preview" class={"p-2 rounded-lg #{@t.hover} #{@t.muted}"}>
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>

      <div class="flex-1 overflow-y-auto">
        <div class="p-6">
          <div class={"w-full aspect-video rounded-2xl flex items-center justify-center mb-4 #{file_bg(@file.file_name)}"}>
            <.icon name={file_icon(@file.file_name)} class="w-20 h-20 text-white" />
          </div>
          <h4 class={"text-xl font-bold break-words mb-1 #{@t.text}"}>{@file.file_name}</h4>
          <p class={"text-sm #{@t.muted}"}>{@ext} File • {fmt_size(@file.file_size)}</p>
        </div>

        <div class={"h-px #{@t.divider}"}></div>

        <div class="p-6 space-y-6">
          <div>
            <h5 class={"text-xs font-medium uppercase tracking-wider mb-3 #{@t.subtle}"}>Status</h5>
            <.status_badge status={@file.status} />
          </div>

          <div>
            <h5 class={"text-xs font-medium uppercase tracking-wider mb-3 #{@t.subtle}"}>
              Properties
            </h5>
            <div class={["rounded-xl divide-y", @t.row, @t.border]}>
              <.property_row label="Type" value={@ext || "Unknown"} icon="hero-document" t={@t} />
              <.property_row
                label="Category"
                value={to_string(@category) |> String.capitalize()}
                icon="hero-folder"
                t={@t}
              />
              <.property_row label="Size" value={fmt_size(@file.file_size)} icon="hero-scale" t={@t} />
              <.property_row label="MIME Type" value={@mime} icon="hero-code-bracket" t={@t} />
              <.property_row
                label="Uploaded"
                value={fmt_datetime(@file.inserted_at)}
                icon="hero-calendar"
                t={@t}
              />
            </div>
          </div>

          <div>
            <h5 class={"text-xs font-medium uppercase tracking-wider mb-3 #{@t.subtle}"}>Sharing</h5>
            <div class="grid grid-cols-2 gap-3">
              <div class={["p-4 rounded-xl text-center", @t.row]}>
                <p class={"text-2xl font-bold #{@t.text}"}>{length(@shares)}</p>
                <p class={"text-xs #{@t.muted}"}>Share Links</p>
              </div>
              <div class={["p-4 rounded-xl text-center", @t.row]}>
                <p class={"text-2xl font-bold #{@t.text}"}>{@total_downloads}</p>
                <p class={"text-xs #{@t.muted}"}>Downloads</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class={"p-4 border-t space-y-2 #{@t.border}"}>
        <button
          phx-click="create_share_link"
          phx-value-id={@file.id}
          class="w-full py-3 px-4 bg-gradient-to-r from-cyan-500 to-blue-500 text-white font-medium rounded-xl hover:from-cyan-600 hover:to-blue-600 flex items-center justify-center gap-2"
        >
          <.icon name="hero-link" class="w-5 h-5" /> Create Share Link
        </button>
        <div class="grid grid-cols-2 gap-2">
          <button class={[
            "py-2.5 px-4 font-medium rounded-xl flex items-center justify-center gap-2",
            if(@theme == "light",
              do: "bg-gray-100 text-gray-700 hover:bg-gray-200",
              else: "bg-slate-700/50 text-white hover:bg-slate-700"
            )
          ]}>
            <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Download
          </button>
          <button class={[
            "py-2.5 px-4 font-medium rounded-xl flex items-center justify-center gap-2",
            if(@theme == "light",
              do: "bg-gray-100 text-gray-700 hover:bg-gray-200",
              else: "bg-slate-700/50 text-white hover:bg-slate-700"
            )
          ]}>
            <.icon name="hero-pencil" class="w-4 h-4" /> Rename
          </button>
        </div>
        <button
          phx-click="delete_transfer"
          phx-value-id={@file.id}
          data-confirm="Delete this file?"
          class="w-full py-2.5 px-4 bg-red-500/10 text-red-500 font-medium rounded-xl hover:bg-red-500/20 flex items-center justify-center gap-2"
        >
          <.icon name="hero-trash" class="w-4 h-4" /> Delete File
        </button>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :t, :map, required: true

  defp property_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 p-3">
      <.icon name={@icon} class={"w-4 h-4 #{@t.subtle}"} />
      <span class={"flex-1 text-sm #{@t.muted}"}>{@label}</span>
      <span class={"text-sm font-medium #{@t.text} truncate max-w-[150px]"}>{@value}</span>
    </div>
    """
  end

  # Upload modal
  attr :uploads, :any, required: true
  attr :progress, :map, required: true
  attr :t, :map, required: true
  attr :theme, :string, required: true

  defp upload_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="close_upload_modal"></div>
      <div class={["relative w-full max-w-2xl mx-4 rounded-2xl border shadow-2xl", @t.card]}>
        <div class={"p-6 border-b flex items-center justify-between #{@t.border}"}>
          <h2 class={"text-xl font-bold #{@t.text}"}>Upload Files</h2>
          <button phx-click="close_upload_modal" class={"p-2 rounded-lg #{@t.hover} #{@t.muted}"}>
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>
        <div class="p-6">
          <form phx-change="validate" phx-submit="start_upload">
            <div
              class={"border-2 border-dashed rounded-2xl p-8 text-center hover:border-cyan-500 #{@t.border}"}
              phx-drop-target={@uploads.files.ref}
            >
              <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center">
                <.icon name="hero-cloud-arrow-up" class="w-8 h-8 text-cyan-400" />
              </div>
              <p class={"font-medium mb-1 #{@t.text}"}>Drag & drop files here</p>
              <p class={"text-sm mb-4 #{@t.muted}"}>or click to browse</p>
              <label class={[
                "inline-flex items-center gap-2 px-4 py-2 rounded-xl cursor-pointer",
                if(@theme == "light",
                  do: "bg-gray-100 hover:bg-gray-200 text-gray-700",
                  else: "bg-slate-700/50 hover:bg-slate-700 text-white"
                )
              ]}>
                <.icon name="hero-folder-open" class="w-5 h-5" /> Browse Files
                <.live_file_input upload={@uploads.files} class="hidden" />
              </label>
            </div>
            <%= if Enum.any?(@uploads.files.entries) do %>
              <div class="mt-6 space-y-3">
                <%= for e <- @uploads.files.entries do %>
                  <div class={["p-4 rounded-xl", @t.row]}>
                    <div class="flex items-center justify-between mb-2">
                      <div class="flex items-center gap-3">
                        <div class={"w-10 h-10 rounded-lg flex items-center justify-center #{file_bg(e.client_name)}"}>
                          <.icon name={file_icon(e.client_name)} class="w-5 h-5 text-white" />
                        </div>
                        <div>
                          <p class={"font-medium text-sm truncate max-w-[300px] #{@t.text}"}>
                            {e.client_name}
                          </p>
                          <p class={"text-xs #{@t.muted}"}>{fmt_size(e.client_size)}</p>
                        </div>
                      </div>
                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={e.ref}
                        class={"hover:text-red-400 #{@t.muted}"}
                      >
                        <.icon name="hero-x-mark" class="w-5 h-5" />
                      </button>
                    </div>
                    <div class={"h-1.5 rounded-full overflow-hidden #{@t.progress}"}>
                      <div
                        class="h-full bg-gradient-to-r from-cyan-400 to-blue-500 rounded-full"
                        style={"width: #{Map.get(@progress, e.ref, 0)}%"}
                      />
                    </div>
                  </div>
                <% end %>
              </div>
              <button
                type="submit"
                class="mt-6 w-full py-3 px-4 bg-gradient-to-r from-cyan-500 to-blue-500 text-white font-medium rounded-xl hover:from-cyan-600 hover:to-blue-600"
              >
                Upload {length(@uploads.files.entries)} files
              </button>
            <% end %>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # Helpers
  defp file_bg(name) do
    ext = Path.extname(name || "") |> String.downcase()

    cond do
      ext in ~w(.jpg .jpeg .png .gif .webp .svg) -> "bg-gradient-to-br from-pink-500 to-rose-500"
      ext in ~w(.mp4 .mov .avi .mkv .webm) -> "bg-gradient-to-br from-purple-500 to-violet-500"
      ext in ~w(.mp3 .wav .flac .aac) -> "bg-gradient-to-br from-green-500 to-emerald-500"
      ext in ~w(.pdf) -> "bg-gradient-to-br from-red-500 to-orange-500"
      ext in ~w(.doc .docx .txt .rtf) -> "bg-gradient-to-br from-blue-500 to-cyan-500"
      ext in ~w(.xls .xlsx) -> "bg-gradient-to-br from-green-600 to-teal-500"
      ext in ~w(.zip .rar .7z .tar .gz) -> "bg-gradient-to-br from-amber-500 to-orange-500"
      true -> "bg-gradient-to-br from-slate-500 to-slate-600"
    end
  end

  defp fmt_size(nil), do: "0 B"

  defp fmt_size(b) when is_integer(b) do
    cond do
      b >= 1_000_000_000 -> "#{Float.round(b / 1_000_000_000, 2)} GB"
      b >= 1_000_000 -> "#{Float.round(b / 1_000_000, 2)} MB"
      b >= 1_000 -> "#{Float.round(b / 1_000, 2)} KB"
      true -> "#{b} B"
    end
  end

  defp fmt_size(_), do: "0 B"

  defp fmt_storage(b) when is_integer(b) do
    cond do
      b >= 1_000_000_000 -> "#{Float.round(b / 1_000_000_000, 1)} GB"
      b >= 1_000_000 -> "#{Float.round(b / 1_000_000, 1)} MB"
      true -> "#{Float.round(b / 1_000, 1)} KB"
    end
  end

  defp fmt_storage(_), do: "0 KB"

  defp fmt_date(nil), do: ""
  defp fmt_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp fmt_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")

  defp fmt_datetime(nil), do: ""
  defp fmt_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y at %I:%M %p")
  defp fmt_datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y at %I:%M %p")

  defp fmt_rel(nil), do: "Never"

  defp fmt_rel(%DateTime{} = dt) do
    diff = DateTime.diff(dt, DateTime.utc_now(), :second)

    cond do
      diff < 0 -> "Expired"
      diff < 3600 -> "in #{div(diff, 60)} min"
      diff < 86400 -> "in #{div(diff, 3600)}h"
      true -> "in #{div(diff, 86400)}d"
    end
  end

  defp act_desc(:upload, "completed"), do: "File uploaded successfully"
  defp act_desc(:upload, "pending"), do: "Upload pending"
  defp act_desc(:upload, "uploading"), do: "Upload in progress"
  defp act_desc(:upload, "failed"), do: "Upload failed"
  defp act_desc(_, _), do: "Activity"
end
