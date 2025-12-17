defmodule FiletransferWeb.Admin.WaitlistLive do
  use FiletransferWeb, :live_view

  alias FiletransferCore.Waitlist
  alias FiletransferCore.Repo
  alias FiletransferCore.Waitlist.WaitlistEntry
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(30_000, self(), :refresh)
    end

    socket =
      socket
      |> assign(:page_title, "Waitlist")
      |> assign(:search_query, "")
      |> assign(:status_filter, "all")
      |> assign_stats()
      |> assign_filtered_entries()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign_stats()
     |> assign_filtered_entries()}
  end

  @impl true
  def handle_event("export", _params, socket) do
    {:noreply, redirect(socket, to: "/admin/waitlist/export")}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign_filtered_entries()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:status_filter, status)
      |> assign_filtered_entries()

    {:noreply, socket}
  end

  @impl true
  def handle_event("notify", %{"id" => id}, socket) do
    entry = Waitlist.get_waitlist_entry!(id)
    {:ok, _updated} = Waitlist.mark_as_notified(entry)

    socket =
      socket
      |> assign_stats()
      |> assign_filtered_entries()

    {:noreply, socket}
  end

  @impl true
  def handle_event("convert", %{"id" => id}, socket) do
    entry = Waitlist.get_waitlist_entry!(id)
    {:ok, _updated} = Waitlist.mark_as_converted(entry)

    socket =
      socket
      |> assign_stats()
      |> assign_filtered_entries()

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    entry = Waitlist.get_waitlist_entry!(id)
    {:ok, _deleted} = Waitlist.delete_waitlist_entry(entry)

    socket =
      socket
      |> assign_stats()
      |> assign_filtered_entries()

    {:noreply, socket}
  end

  defp assign_filtered_entries(socket) do
    entries =
      case {socket.assigns.search_query, socket.assigns.status_filter} do
        {"", "all"} ->
          Waitlist.list_waitlist_entries()

        {query, "all"} when query != "" ->
          Waitlist.search_entries(query)

        {"", status} ->
          Waitlist.filter_by_status(status)

        {query, status} ->
          # Combine search and filter
          Waitlist.search_entries(query)
          |> Enum.filter(fn entry ->
            case status do
              "pending" -> is_nil(entry.notified_at) and is_nil(entry.converted_at)
              "notified" -> not is_nil(entry.notified_at) and is_nil(entry.converted_at)
              "converted" -> not is_nil(entry.converted_at)
              _ -> true
            end
          end)
      end

    stream(socket, :entries, entries, reset: true)
  end

  defp assign_stats(socket) do
    total = Waitlist.count_waitlist_entries()

    week_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    recent =
      Repo.aggregate(
        from(w in WaitlistEntry, where: w.inserted_at > ^week_ago),
        :count,
        :id
      )

    day_ago = DateTime.add(DateTime.utc_now(), -1, :day)

    today =
      Repo.aggregate(
        from(w in WaitlistEntry, where: w.inserted_at > ^day_ago),
        :count,
        :id
      )

    use_cases =
      Repo.all(
        from(w in WaitlistEntry,
          where: not is_nil(w.use_case) and w.use_case != "",
          group_by: w.use_case,
          select: {w.use_case, count(w.id)},
          order_by: [desc: count(w.id)],
          limit: 5
        )
      )

    # New analytics data
    growth_rate = Waitlist.growth_rate()
    status_breakdown = Waitlist.status_breakdown()
    daily_signups = Waitlist.daily_signups(14)

    socket
    |> assign(:total_count, total)
    |> assign(:week_count, recent)
    |> assign(:today_count, today)
    |> assign(:use_cases, use_cases)
    |> assign(:growth_rate, growth_rate)
    |> assign(:status_breakdown, status_breakdown)
    |> assign(:daily_signups, daily_signups)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 dark:bg-zinc-950 transition-colors duration-300">
      <%!-- Sidebar - Collapsed on mobile, expanded on desktop --%>
      <aside class="fixed inset-y-0 left-0 w-16 lg:w-72 bg-white dark:bg-zinc-900 border-r border-zinc-200 dark:border-zinc-800 transition-all duration-300 z-50">
        <%!-- Logo --%>
        <div class="flex items-center gap-3 px-3 lg:px-6 py-5">
          <div class="w-10 h-10 rounded-2xl bg-zinc-900 dark:bg-white flex items-center justify-center flex-shrink-0">
            <.icon name="hero-bolt" class="w-5 h-5 text-white dark:text-zinc-900" />
          </div>
          <div class="hidden lg:block">
            <h1 class="text-lg font-bold text-zinc-900 dark:text-white tracking-tight">
              ZipShare
            </h1>
            <p class="text-xs text-zinc-500 dark:text-zinc-400 font-medium">Command Center</p>
          </div>
        </div>

        <%!-- Navigation --%>
        <nav class="px-2 lg:px-4 mt-4">
          <p class="hidden lg:block px-3 mb-3 text-[10px] font-bold text-zinc-400 dark:text-zinc-600 uppercase tracking-widest">
            Overview
          </p>
          <div class="space-y-1">
            <.nav_item
              href="/admin/waitlist"
              icon="hero-clipboard-document-list"
              label="Waitlist"
              active
              badge={@total_count}
            />
            <.nav_item href="#" icon="hero-users" label="Users" badge="Soon" muted />
            <.nav_item href="#" icon="hero-arrow-up-tray" label="Transfers" badge="Soon" muted />
            <.nav_item href="#" icon="hero-chart-bar" label="Analytics" badge="Soon" muted />
          </div>

          <p class="hidden lg:block px-3 mb-3 mt-8 text-[10px] font-bold text-zinc-400 dark:text-zinc-600 uppercase tracking-widest">
            Settings
          </p>
          <div class="space-y-1 mt-6 lg:mt-0">
            <.nav_item href="#" icon="hero-cog-6-tooth" label="Configuration" muted />
            <.nav_item href="#" icon="hero-key" label="API Keys" muted />
          </div>
        </nav>

        <%!-- Theme Toggle & Back --%>
        <div class="absolute bottom-0 left-0 right-0 p-2 lg:p-4 space-y-2 lg:space-y-3 border-t border-zinc-200 dark:border-zinc-800">
          <%!-- Theme toggle - simplified on mobile --%>
          <div class="flex items-center justify-center lg:justify-between px-1 lg:px-3 py-2 rounded-xl bg-zinc-100 dark:bg-zinc-800">
            <span class="hidden lg:block text-sm text-zinc-600 dark:text-zinc-400">Theme</span>
            <div class="flex items-center gap-1 p-1 rounded-lg bg-zinc-200 dark:bg-zinc-700">
              <button
                phx-click={JS.dispatch("phx:set-theme")}
                data-phx-theme="light"
                class="p-1.5 rounded-md text-zinc-500 hover:text-zinc-900 dark:hover:text-white [[data-theme=light]_&]:bg-white [[data-theme=light]_&]:text-zinc-900 [[data-theme=light]_&]:shadow-sm transition-all"
              >
                <.icon name="hero-sun" class="w-4 h-4" />
              </button>
              <button
                phx-click={JS.dispatch("phx:set-theme")}
                data-phx-theme="dark"
                class="p-1.5 rounded-md text-zinc-500 hover:text-zinc-900 dark:hover:text-white [[data-theme=dark]_&]:bg-zinc-600 [[data-theme=dark]_&]:text-white transition-all"
              >
                <.icon name="hero-moon" class="w-4 h-4" />
              </button>
              <button
                phx-click={JS.dispatch("phx:set-theme")}
                data-phx-theme="system"
                class="hidden lg:block p-1.5 rounded-md text-zinc-500 hover:text-zinc-900 dark:hover:text-white [html:not([data-theme])_&]:bg-white dark:[html:not([data-theme])_&]:bg-zinc-600 transition-all"
              >
                <.icon name="hero-computer-desktop" class="w-4 h-4" />
              </button>
            </div>
          </div>
          <a
            href="/"
            class="flex items-center justify-center lg:justify-start gap-2 px-3 py-2 text-zinc-500 hover:text-zinc-900 dark:hover:text-white transition-colors text-sm"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            <span class="hidden lg:inline">Back to App</span>
          </a>
        </div>
      </aside>

      <%!-- Main content - adjusts padding based on sidebar width --%>
      <main class="pl-16 lg:pl-72 min-h-screen transition-all duration-300">
        <div class="p-4 lg:p-8 max-w-6xl mx-auto">
          <%!-- Header --%>
          <div class="flex flex-col sm:flex-row sm:items-start justify-between gap-4 mb-6 lg:mb-10">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <h1 class="text-2xl lg:text-3xl font-bold text-zinc-900 dark:text-white tracking-tight">
                  Waitlist
                </h1>
                <span class="px-2.5 py-1 text-xs font-bold bg-emerald-100 dark:bg-emerald-900/50 text-emerald-700 dark:text-emerald-400 rounded-full">
                  Live
                </span>
              </div>
              <p class="text-sm text-zinc-500 dark:text-zinc-400">
                {Calendar.strftime(DateTime.utc_now(), "%B %d, %Y")}
              </p>
            </div>
            <button
              phx-click="export"
              class="group flex items-center justify-center gap-2 px-4 lg:px-5 py-2.5 lg:py-3 bg-zinc-900 dark:bg-white text-white dark:text-zinc-900 rounded-xl lg:rounded-2xl font-semibold hover:scale-105 active:scale-95 transition-all duration-200 shadow-xl shadow-zinc-900/10 dark:shadow-none text-sm lg:text-base"
            >
              <.icon
                name="hero-arrow-down-tray"
                class="w-4 h-4 lg:w-5 lg:h-5 group-hover:-translate-y-0.5 transition-transform"
              />
              <span class="hidden sm:inline">Export CSV</span>
              <span class="sm:hidden">Export</span>
            </button>
          </div>

          <%!-- Stats Grid - Enhanced with growth indicators --%>
          <div class="grid grid-cols-2 lg:grid-cols-6 gap-3 lg:gap-4 mb-6 lg:mb-8">
            <%!-- Total - Large card with growth indicator --%>
            <div class="col-span-2 lg:row-span-2 p-4 lg:p-6 rounded-2xl lg:rounded-3xl bg-zinc-900 dark:bg-white text-white dark:text-zinc-900 relative overflow-hidden group">
              <div class="absolute -right-6 -bottom-6 lg:-right-8 lg:-bottom-8 opacity-10 group-hover:opacity-20 transition-opacity">
                <.icon name="hero-envelope" class="w-24 h-24 lg:w-32 lg:h-32" />
              </div>
              <p class="text-xs lg:text-sm font-medium text-zinc-400 dark:text-zinc-500 mb-1">
                Total Signups
              </p>
              <p class="text-4xl lg:text-6xl font-bold tracking-tight">{@total_count}</p>
              <div class="flex items-center gap-2 mt-2 lg:mt-4">
                <.growth_indicator rate={@growth_rate} inverted />
                <span class="text-xs text-zinc-500 dark:text-zinc-400">vs last week</span>
              </div>
            </div>

            <%!-- This Week with sparkline --%>
            <div class="col-span-1 lg:col-span-2 p-4 lg:p-5 rounded-2xl lg:rounded-3xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs lg:text-sm text-zinc-500 dark:text-zinc-400 mb-1">This Week</p>
                  <p class="text-2xl lg:text-3xl font-bold text-zinc-900 dark:text-white">
                    {@week_count}
                  </p>
                </div>
                <div class="w-10 h-10 lg:w-12 lg:h-12 rounded-xl lg:rounded-2xl bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center">
                  <.icon
                    name="hero-calendar"
                    class="w-5 h-5 lg:w-6 lg:h-6 text-blue-600 dark:text-blue-400"
                  />
                </div>
              </div>
              <%!-- Mini sparkline --%>
              <div class="mt-3 hidden lg:block">
                <.sparkline data={@daily_signups} />
              </div>
            </div>

            <%!-- Today --%>
            <div class="col-span-1 lg:col-span-2 p-4 lg:p-5 rounded-2xl lg:rounded-3xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-xs lg:text-sm text-zinc-500 dark:text-zinc-400 mb-1">Today</p>
                  <p class="text-2xl lg:text-3xl font-bold text-zinc-900 dark:text-white">
                    {@today_count}
                  </p>
                </div>
                <div class="w-10 h-10 lg:w-12 lg:h-12 rounded-xl lg:rounded-2xl bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center">
                  <.icon
                    name="hero-bolt"
                    class="w-5 h-5 lg:w-6 lg:h-6 text-amber-600 dark:text-amber-400"
                  />
                </div>
              </div>
              <%!-- Status breakdown mini --%>
              <div class="mt-3 hidden lg:flex items-center gap-2">
                <.status_mini_badge
                  count={@status_breakdown.pending}
                  label="Pending"
                  color="zinc"
                />
                <.status_mini_badge
                  count={@status_breakdown.notified}
                  label="Notified"
                  color="blue"
                />
                <.status_mini_badge
                  count={@status_breakdown.converted}
                  label="Converted"
                  color="emerald"
                />
              </div>
            </div>

            <%!-- Use Cases Section - Redesigned with visual impact --%>
            <div class="col-span-2 lg:col-span-4 p-4 lg:p-6 rounded-2xl lg:rounded-3xl bg-gradient-to-br from-slate-50 via-white to-slate-50 dark:from-zinc-900 dark:via-zinc-900 dark:to-zinc-800 border border-zinc-200 dark:border-zinc-800 shadow-sm">
              <div class="flex items-center justify-between mb-5 lg:mb-6">
                <div>
                  <h3 class="font-bold text-zinc-900 dark:text-white text-base lg:text-lg tracking-tight">
                    What people want to use it for
                  </h3>
                  <p class="text-xs lg:text-sm text-zinc-500 dark:text-zinc-400 mt-0.5">
                    Top use cases from signups
                  </p>
                </div>
                <div class="w-10 h-10 lg:w-12 lg:h-12 rounded-2xl bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center shadow-lg shadow-purple-500/25">
                  <svg
                    class="w-5 h-5 lg:w-6 lg:h-6 text-white"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    stroke-width="2"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456z"
                    />
                  </svg>
                </div>
              </div>

              <%= if @use_cases == [] do %>
                <div class="flex flex-col items-center justify-center py-10 lg:py-12 text-center">
                  <div class="w-16 h-16 rounded-full bg-zinc-100 dark:bg-zinc-800 flex items-center justify-center mb-4">
                    <svg
                      class="w-8 h-8 text-zinc-400 dark:text-zinc-500"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="1.5"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z"
                      />
                    </svg>
                  </div>
                  <p class="text-zinc-500 dark:text-zinc-400 text-sm font-medium">
                    No use cases shared yet
                  </p>
                  <p class="text-zinc-400 dark:text-zinc-500 text-xs mt-1">
                    Data will appear as users sign up
                  </p>
                </div>
              <% else %>
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 lg:gap-4">
                  <%= for {{use_case, count}, index} <- Enum.with_index(@use_cases) do %>
                    <% {icon_svg, gradient_from, gradient_to, badge_bg, badge_text, shadow_color} =
                      get_use_case_style(use_case, index) %>
                    <div class="group relative p-4 lg:p-5 rounded-2xl bg-white dark:bg-zinc-800/80 border border-zinc-200/80 dark:border-zinc-700/50 transition-all duration-300 hover:scale-[1.03] hover:shadow-xl hover:shadow-zinc-200/50 dark:hover:shadow-zinc-900/50 hover:border-zinc-300 dark:hover:border-zinc-600 overflow-hidden">
                      <%!-- Background gradient accent --%>
                      <div class={"absolute inset-0 opacity-[0.03] dark:opacity-[0.08] bg-gradient-to-br #{gradient_from} #{gradient_to}"} />

                      <%!-- Rank badge --%>
                      <div class={"absolute top-3 right-3 w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold #{badge_bg} #{badge_text}"}>
                        {index + 1}
                      </div>

                      <%!-- Icon with gradient background --%>
                      <div class={"w-11 h-11 lg:w-12 lg:h-12 rounded-xl bg-gradient-to-br #{gradient_from} #{gradient_to} flex items-center justify-center mb-3 shadow-lg #{shadow_color} group-hover:scale-110 transition-transform duration-300"}>
                        {raw(icon_svg)}
                      </div>

                      <%!-- Use case name --%>
                      <h4 class="font-semibold text-zinc-900 dark:text-white text-sm lg:text-base mb-1 truncate pr-8">
                        {use_case}
                      </h4>

                      <%!-- Count with visual indicator --%>
                      <div class="flex items-center gap-2">
                        <div class="flex -space-x-1">
                          <%= for i <- 0..min(count - 1, 2) do %>
                            <div class={"w-5 h-5 rounded-full border-2 border-white dark:border-zinc-800 bg-gradient-to-br #{gradient_from} #{gradient_to} flex items-center justify-center"}>
                              <span class="text-[8px] font-bold text-white">
                                {String.at(use_case, i) |> String.upcase()}
                              </span>
                            </div>
                          <% end %>
                          <%= if count > 3 do %>
                            <div class="w-5 h-5 rounded-full border-2 border-white dark:border-zinc-800 bg-zinc-200 dark:bg-zinc-700 flex items-center justify-center">
                              <span class="text-[8px] font-bold text-zinc-600 dark:text-zinc-300">
                                +{count - 3}
                              </span>
                            </div>
                          <% end %>
                        </div>
                        <span class="text-xs text-zinc-500 dark:text-zinc-400 font-medium">
                          {count} {if count == 1, do: "person", else: "people"}
                        </span>
                      </div>

                      <%!-- Progress bar --%>
                      <div class="mt-3 h-1.5 bg-zinc-100 dark:bg-zinc-700 rounded-full overflow-hidden">
                        <div
                          class={"h-full rounded-full bg-gradient-to-r #{gradient_from} #{gradient_to} transition-all duration-700 ease-out"}
                          style={"width: #{count / max(Enum.at(@use_cases, 0) |> elem(1), 1) * 100}%"}
                        />
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Entries Table with Search/Filter --%>
          <div class="rounded-2xl lg:rounded-3xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 overflow-hidden">
            <div class="px-4 lg:px-6 py-4 lg:py-5 border-b border-zinc-200 dark:border-zinc-800">
              <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
                <div class="flex items-center gap-2 lg:gap-3">
                  <.icon name="hero-clipboard-document-list" class="w-5 h-5 text-zinc-400" />
                  <h2 class="font-bold text-zinc-900 dark:text-white text-sm lg:text-base">
                    All Signups
                  </h2>
                  <span class="text-xs lg:text-sm text-zinc-500 dark:text-zinc-400">
                    {@total_count} total
                  </span>
                </div>

                <%!-- Search and Filter Controls --%>
                <div class="flex flex-col sm:flex-row gap-3">
                  <%!-- Search Input --%>
                  <div class="relative">
                    <.icon
                      name="hero-magnifying-glass"
                      class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400"
                    />
                    <input
                      type="text"
                      placeholder="Search by email, name..."
                      value={@search_query}
                      phx-keyup="search"
                      phx-debounce="300"
                      name="query"
                      class="pl-10 pr-4 py-2 w-full sm:w-64 text-sm rounded-xl border border-zinc-200 dark:border-zinc-700 bg-zinc-50 dark:bg-zinc-800 text-zinc-900 dark:text-white placeholder-zinc-400 focus:outline-none focus:ring-2 focus:ring-zinc-900 dark:focus:ring-white focus:border-transparent"
                    />
                  </div>

                  <%!-- Status Filter --%>
                  <div class="relative">
                    <select
                      phx-change="filter_status"
                      name="status"
                      class="appearance-none pl-4 pr-10 py-2 text-sm rounded-xl border border-zinc-200 dark:border-zinc-700 bg-zinc-50 dark:bg-zinc-800 text-zinc-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-zinc-900 dark:focus:ring-white focus:border-transparent cursor-pointer"
                    >
                      <option value="all" selected={@status_filter == "all"}>All Status</option>
                      <option value="pending" selected={@status_filter == "pending"}>Pending</option>
                      <option value="notified" selected={@status_filter == "notified"}>
                        Notified
                      </option>
                      <option value="converted" selected={@status_filter == "converted"}>
                        Converted
                      </option>
                    </select>
                    <.icon
                      name="hero-chevron-down"
                      class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-400 pointer-events-none"
                    />
                  </div>
                </div>
              </div>
            </div>

            <%= if @total_count == 0 do %>
              <div class="px-4 lg:px-6 py-12 lg:py-16 text-center">
                <.icon
                  name="hero-inbox"
                  class="w-12 h-12 lg:w-16 lg:h-16 text-zinc-300 dark:text-zinc-600 mx-auto mb-4"
                />
                <h3 class="text-base lg:text-lg font-semibold text-zinc-900 dark:text-white mb-2">
                  No signups yet
                </h3>
                <p class="text-xs lg:text-sm text-zinc-500 dark:text-zinc-400">
                  Share your landing page to start collecting leads
                </p>
              </div>
            <% else %>
              <%!-- Mobile Card View --%>
              <div
                class="lg:hidden divide-y divide-zinc-200 dark:divide-zinc-800"
                id="entries-mobile"
                phx-update="stream"
              >
                <div
                  :for={{dom_id, entry} <- @streams.entries}
                  id={"#{dom_id}-mobile"}
                  class="p-4 hover:bg-zinc-50 dark:hover:bg-zinc-800/50"
                >
                  <div class="flex items-start gap-3">
                    <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-zinc-200 to-zinc-300 dark:from-zinc-700 dark:to-zinc-600 flex items-center justify-center text-sm font-bold text-zinc-600 dark:text-zinc-300 flex-shrink-0">
                      {get_initials(entry.name, entry.email)}
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="font-medium text-zinc-900 dark:text-white text-sm">
                        {entry.name || "Anonymous"}
                      </p>
                      <p class="text-xs text-zinc-500 dark:text-zinc-400 truncate">{entry.email}</p>
                      <div class="flex items-center gap-2 mt-2 flex-wrap">
                        <%= if entry.use_case && entry.use_case != "" do %>
                          <span class="inline-flex px-2 py-1 rounded-lg text-xs font-medium bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300">
                            {entry.use_case}
                          </span>
                        <% end %>
                        <span class="text-xs text-zinc-400">
                          {format_relative_date(entry.inserted_at)}
                        </span>
                      </div>
                      <%!-- Quick Actions Mobile --%>
                      <div class="flex items-center gap-2 mt-3">
                        <.quick_action_button
                          :if={is_nil(entry.notified_at)}
                          action="notify"
                          id={entry.id}
                          icon="hero-paper-airplane"
                          label="Notify"
                          color="blue"
                        />
                        <.quick_action_button
                          :if={is_nil(entry.converted_at)}
                          action="convert"
                          id={entry.id}
                          icon="hero-check-circle"
                          label="Convert"
                          color="emerald"
                        />
                        <.quick_action_button
                          action="delete"
                          id={entry.id}
                          icon="hero-trash"
                          label="Delete"
                          color="red"
                          confirm="Are you sure you want to delete this entry?"
                        />
                      </div>
                    </div>
                    <.status_pill notified={entry.notified_at} converted={entry.converted_at} compact />
                  </div>
                </div>
              </div>

              <%!-- Desktop Table View --%>
              <div class="hidden lg:block overflow-x-auto">
                <table class="w-full">
                  <thead>
                    <tr class="border-b border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-800/50">
                      <th class="px-6 py-4 text-left text-xs font-bold text-zinc-500 dark:text-zinc-400 uppercase tracking-wider">
                        Person
                      </th>
                      <th class="px-6 py-4 text-left text-xs font-bold text-zinc-500 dark:text-zinc-400 uppercase tracking-wider">
                        Use Case
                      </th>
                      <th class="px-6 py-4 text-left text-xs font-bold text-zinc-500 dark:text-zinc-400 uppercase tracking-wider">
                        Source
                      </th>
                      <th class="px-6 py-4 text-left text-xs font-bold text-zinc-500 dark:text-zinc-400 uppercase tracking-wider">
                        Joined
                      </th>
                      <th class="px-6 py-4 text-left text-xs font-bold text-zinc-500 dark:text-zinc-400 uppercase tracking-wider">
                        Status
                      </th>
                      <th class="px-6 py-4 text-right text-xs font-bold text-zinc-500 dark:text-zinc-400 uppercase tracking-wider">
                        Actions
                      </th>
                    </tr>
                  </thead>
                  <tbody
                    id="entries"
                    phx-update="stream"
                    class="divide-y divide-zinc-200 dark:divide-zinc-800"
                  >
                    <tr
                      :for={{dom_id, entry} <- @streams.entries}
                      id={dom_id}
                      class="hover:bg-zinc-50 dark:hover:bg-zinc-800/50 transition-colors group"
                    >
                      <td class="px-6 py-4">
                        <div class="flex items-center gap-3">
                          <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-zinc-200 to-zinc-300 dark:from-zinc-700 dark:to-zinc-600 flex items-center justify-center text-sm font-bold text-zinc-600 dark:text-zinc-300">
                            {get_initials(entry.name, entry.email)}
                          </div>
                          <div>
                            <p class="font-medium text-zinc-900 dark:text-white">
                              {entry.name || "Anonymous"}
                            </p>
                            <p class="text-sm text-zinc-500 dark:text-zinc-400">{entry.email}</p>
                          </div>
                        </div>
                      </td>
                      <td class="px-6 py-4">
                        <%= if entry.use_case && entry.use_case != "" do %>
                          <span class="inline-flex px-3 py-1.5 rounded-xl text-xs font-semibold bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300">
                            {entry.use_case}
                          </span>
                        <% else %>
                          <span class="text-zinc-400 dark:text-zinc-600 text-sm">—</span>
                        <% end %>
                      </td>
                      <td class="px-6 py-4">
                        <span class="text-sm text-zinc-600 dark:text-zinc-400">
                          {entry.source || "direct"}
                        </span>
                      </td>
                      <td class="px-6 py-4">
                        <span class="text-sm text-zinc-600 dark:text-zinc-400">
                          {format_relative_date(entry.inserted_at)}
                        </span>
                      </td>
                      <td class="px-6 py-4">
                        <.status_pill notified={entry.notified_at} converted={entry.converted_at} />
                      </td>
                      <td class="px-6 py-4">
                        <div class="flex items-center justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                          <.quick_action_button
                            :if={is_nil(entry.notified_at)}
                            action="notify"
                            id={entry.id}
                            icon="hero-paper-airplane"
                            label="Notify"
                            color="blue"
                          />
                          <.quick_action_button
                            :if={is_nil(entry.converted_at)}
                            action="convert"
                            id={entry.id}
                            icon="hero-check-circle"
                            label="Convert"
                            color="emerald"
                          />
                          <.quick_action_button
                            action="delete"
                            id={entry.id}
                            icon="hero-trash"
                            label="Delete"
                            color="red"
                            confirm="Are you sure you want to delete this entry?"
                          />
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  # Components

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :muted, :boolean, default: false
  attr :badge, :any, default: nil

  defp nav_item(assigns) do
    ~H"""
    <a
      href={@href}
      title={@label}
      class={[
        "flex items-center justify-center lg:justify-start gap-3 p-3 lg:px-3 lg:py-2.5 rounded-xl text-sm font-medium transition-all duration-200",
        @active && "bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-white",
        !@active && !@muted &&
          "text-zinc-600 dark:text-zinc-400 hover:bg-zinc-100 dark:hover:bg-zinc-800 hover:text-zinc-900 dark:hover:text-white",
        @muted && "text-zinc-400 dark:text-zinc-600 cursor-not-allowed opacity-60"
      ]}
    >
      <.icon name={@icon} class="w-5 h-5 flex-shrink-0" />
      <span class="hidden lg:block flex-1">{@label}</span>
      <span
        :if={@badge}
        class={[
          "hidden lg:inline-flex px-2 py-0.5 text-xs font-bold rounded-lg",
          is_integer(@badge) && "bg-zinc-900 dark:bg-white text-white dark:text-zinc-900",
          !is_integer(@badge) && "bg-zinc-200 dark:bg-zinc-700 text-zinc-500 dark:text-zinc-400"
        ]}
      >
        {@badge}
      </span>
    </a>
    """
  end

  attr :index, :integer, required: true

  defp rank_badge(assigns) do
    ~H"""
    <div class={[
      "w-6 h-6 lg:w-7 lg:h-7 rounded-full flex items-center justify-center flex-shrink-0",
      case @index do
        0 -> "bg-amber-200 dark:bg-amber-700"
        1 -> "bg-zinc-200 dark:bg-zinc-600"
        2 -> "bg-orange-200 dark:bg-orange-700"
        _ -> "bg-zinc-100 dark:bg-zinc-700"
      end
    ]}>
      <span class="text-xs font-bold text-zinc-700 dark:text-zinc-200">{@index + 1}</span>
    </div>
    """
  end

  attr :notified, :any, default: nil
  attr :converted, :any, default: nil
  attr :compact, :boolean, default: false

  defp status_pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 font-semibold",
      @compact && "px-2 py-1 rounded-lg text-[10px]",
      !@compact && "px-3 py-1.5 rounded-xl text-xs",
      cond do
        @converted -> "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400"
        @notified -> "bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400"
        true -> "bg-zinc-100 dark:bg-zinc-800 text-zinc-500 dark:text-zinc-400"
      end
    ]}>
      <.icon
        name={
          cond do
            @converted -> "hero-check-circle-mini"
            @notified -> "hero-paper-airplane-mini"
            true -> "hero-clock-mini"
          end
        }
        class={if @compact, do: "flex-shrink-0 w-3 h-3", else: "flex-shrink-0 w-3.5 h-3.5"}
      />
      <span :if={!@compact}>
        <%= cond do %>
          <% @converted -> %>
            Converted
          <% @notified -> %>
            Notified
          <% true -> %>
            Pending
        <% end %>
      </span>
    </span>
    """
  end

  attr :rate, :float, required: true
  attr :inverted, :boolean, default: false

  defp growth_indicator(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-bold",
      cond do
        @rate > 0 ->
          if @inverted,
            do: "bg-emerald-900/50 text-emerald-300",
            else: "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400"

        @rate < 0 ->
          if @inverted,
            do: "bg-red-900/50 text-red-300",
            else: "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400"

        true ->
          if @inverted,
            do: "bg-zinc-700/50 text-zinc-300",
            else: "bg-zinc-100 dark:bg-zinc-800 text-zinc-500 dark:text-zinc-400"
      end
    ]}>
      <.icon
        :if={@rate > 0}
        name="hero-arrow-trending-up-mini"
        class="w-3.5 h-3.5"
      />
      <.icon
        :if={@rate < 0}
        name="hero-arrow-trending-down-mini"
        class="w-3.5 h-3.5"
      />
      <.icon
        :if={@rate == 0}
        name="hero-minus-mini"
        class="w-3.5 h-3.5"
      />
      <span>{abs(@rate)}%</span>
    </div>
    """
  end

  attr :data, :list, required: true

  defp sparkline(assigns) do
    max_value = assigns.data |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 1 end) |> max(1)

    points =
      assigns.data
      |> Enum.with_index()
      |> Enum.map(fn {{_date, count}, index} ->
        x = index / max(length(assigns.data) - 1, 1) * 100
        y = 100 - count / max_value * 100
        {x, y}
      end)

    path =
      points
      |> Enum.map(fn {x, y} -> "#{x},#{y}" end)
      |> Enum.join(" L ")

    assigns = assign(assigns, :path, "M " <> path)
    assigns = assign(assigns, :points, points)

    ~H"""
    <div class="h-10 w-full">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" class="w-full h-full">
        <%!-- Grid lines --%>
        <line
          x1="0"
          y1="50"
          x2="100"
          y2="50"
          stroke="currentColor"
          stroke-opacity="0.1"
          stroke-width="0.5"
        />
        <%!-- Sparkline path --%>
        <path
          d={@path}
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="text-blue-500 dark:text-blue-400"
        />
        <%!-- Dots at each point --%>
        <%= for {x, y} <- @points do %>
          <circle
            cx={x}
            cy={y}
            r="2"
            class="fill-blue-500 dark:fill-blue-400"
          />
        <% end %>
      </svg>
    </div>
    """
  end

  attr :count, :integer, required: true
  attr :label, :string, required: true
  attr :color, :string, required: true

  defp status_mini_badge(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-1 px-2 py-1 rounded-lg text-[10px] font-medium",
      case @color do
        "zinc" -> "bg-zinc-100 dark:bg-zinc-800 text-zinc-600 dark:text-zinc-400"
        "blue" -> "bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400"
        "emerald" -> "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400"
        _ -> "bg-zinc-100 dark:bg-zinc-800 text-zinc-600 dark:text-zinc-400"
      end
    ]}>
      <span class="font-bold">{@count}</span>
      <span>{@label}</span>
    </div>
    """
  end

  attr :action, :string, required: true
  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :color, :string, required: true
  attr :confirm, :string, default: nil

  defp quick_action_button(assigns) do
    ~H"""
    <button
      phx-click={@action}
      phx-value-id={@id}
      data-confirm={@confirm}
      title={@label}
      class={[
        "p-2 rounded-lg transition-all hover:scale-110",
        case @color do
          "blue" -> "text-blue-500 hover:bg-blue-100 dark:hover:bg-blue-900/30"
          "emerald" -> "text-emerald-500 hover:bg-emerald-100 dark:hover:bg-emerald-900/30"
          "red" -> "text-red-500 hover:bg-red-100 dark:hover:bg-red-900/30"
          _ -> "text-zinc-500 hover:bg-zinc-100 dark:hover:bg-zinc-800"
        end
      ]}
    >
      <.icon name={@icon} class="w-4 h-4" />
    </button>
    """
  end

  # Helpers

  # Maps use cases to icons and color schemes
  defp get_use_case_style(use_case, index) do
    use_case_lower = String.downcase(use_case)

    # Define color palettes for variety
    palettes = [
      # Blue - Tech/Software
      {"from-blue-500", "to-indigo-600", "bg-blue-100 dark:bg-blue-900/50",
       "text-blue-700 dark:text-blue-300", "shadow-blue-500/30"},
      # Emerald - Creative/Design
      {"from-emerald-500", "to-teal-600", "bg-emerald-100 dark:bg-emerald-900/50",
       "text-emerald-700 dark:text-emerald-300", "shadow-emerald-500/30"},
      # Violet - Media/Video
      {"from-violet-500", "to-purple-600", "bg-violet-100 dark:bg-violet-900/50",
       "text-violet-700 dark:text-violet-300", "shadow-violet-500/30"},
      # Rose - Marketing/Business
      {"from-rose-500", "to-pink-600", "bg-rose-100 dark:bg-rose-900/50",
       "text-rose-700 dark:text-rose-300", "shadow-rose-500/30"},
      # Amber - Freelance/Personal
      {"from-amber-500", "to-orange-600", "bg-amber-100 dark:bg-amber-900/50",
       "text-amber-700 dark:text-amber-300", "shadow-amber-500/30"},
      # Cyan - Remote/Cloud
      {"from-cyan-500", "to-sky-600", "bg-cyan-100 dark:bg-cyan-900/50",
       "text-cyan-700 dark:text-cyan-300", "shadow-cyan-500/30"}
    ]

    # Match use case to icon and palette
    {icon, palette_index} =
      cond do
        String.contains?(use_case_lower, ["video", "film", "movie", "youtube", "stream"]) ->
          # Violet
          {video_icon(), 2}

        String.contains?(use_case_lower, [
          "photo",
          "image",
          "design",
          "creative",
          "art",
          "graphic"
        ]) ->
          # Emerald
          {design_icon(), 1}

        String.contains?(use_case_lower, ["marketing", "agency", "business", "advertis"]) ->
          # Rose
          {marketing_icon(), 3}

        String.contains?(use_case_lower, [
          "software",
          "developer",
          "code",
          "tech",
          "engineer",
          "dev"
        ]) ->
          # Blue
          {code_icon(), 0}

        String.contains?(use_case_lower, ["remote", "team", "collaborat", "work"]) ->
          # Cyan
          {team_icon(), 5}

        String.contains?(use_case_lower, ["freelance", "personal", "individual"]) ->
          # Amber
          {freelance_icon(), 4}

        String.contains?(use_case_lower, ["backup", "archive", "storage"]) ->
          # Cyan
          {backup_icon(), 5}

        String.contains?(use_case_lower, ["music", "audio", "podcast", "sound"]) ->
          # Violet
          {music_icon(), 2}

        String.contains?(use_case_lower, ["education", "school", "teach", "learn"]) ->
          # Blue
          {education_icon(), 0}

        String.contains?(use_case_lower, ["document", "file", "share"]) ->
          # Emerald
          {document_icon(), 1}

        true ->
          # Fallback - rotate through palettes based on index
          {default_icon(), rem(index, length(palettes))}
      end

    {gradient_from, gradient_to, badge_bg, badge_text, shadow_color} =
      Enum.at(palettes, palette_index)

    {icon, gradient_from, gradient_to, badge_bg, badge_text, shadow_color}
  end

  # SVG Icons - high quality, consistent style
  defp video_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="m15.75 10.5 4.72-4.72a.75.75 0 0 1 1.28.53v11.38a.75.75 0 0 1-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 0 0 2.25-2.25v-9a2.25 2.25 0 0 0-2.25-2.25h-9A2.25 2.25 0 0 0 2.25 7.5v9a2.25 2.25 0 0 0 2.25 2.25Z" /></svg>)
  end

  defp design_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.53 16.122a3 3 0 0 0-5.78 1.128 2.25 2.25 0 0 1-2.4 2.245 4.5 4.5 0 0 0 8.4-2.245c0-.399-.078-.78-.22-1.128Zm0 0a15.998 15.998 0 0 0 3.388-1.62m-5.043-.025a15.994 15.994 0 0 1 1.622-3.395m3.42 3.42a15.995 15.995 0 0 0 4.764-4.648l3.876-5.814a1.151 1.151 0 0 0-1.597-1.597L14.146 6.32a15.996 15.996 0 0 0-4.649 4.763m3.42 3.42a6.776 6.776 0 0 0-3.42-3.42" /></svg>)
  end

  defp marketing_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z" /></svg>)
  end

  defp code_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17.25 6.75 22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3-4.5 16.5" /></svg>)
  end

  defp team_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z" /></svg>)
  end

  defp freelance_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" /></svg>)
  end

  defp backup_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15a4.5 4.5 0 0 0 4.5 4.5H18a3.75 3.75 0 0 0 1.332-7.257 3 3 0 0 0-3.758-3.848 5.25 5.25 0 0 0-10.233 2.33A4.502 4.502 0 0 0 2.25 15Z" /></svg>)
  end

  defp music_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="m9 9 10.5-3m0 6.553v3.75a2.25 2.25 0 0 1-1.632 2.163l-1.32.377a1.803 1.803 0 1 1-.99-3.467l2.31-.66a2.25 2.25 0 0 0 1.632-2.163Zm0 0V2.25L9 5.25v10.303m0 0v3.75a2.25 2.25 0 0 1-1.632 2.163l-1.32.377a1.803 1.803 0 0 1-.99-3.467l2.31-.66A2.25 2.25 0 0 0 9 15.553Z" /></svg>)
  end

  defp education_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4.26 10.147a60.438 60.438 0 0 0-.491 6.347A48.62 48.62 0 0 1 12 20.904a48.62 48.62 0 0 1 8.232-4.41 60.46 60.46 0 0 0-.491-6.347m-15.482 0a50.636 50.636 0 0 0-2.658-.813A59.906 59.906 0 0 1 12 3.493a59.903 59.903 0 0 1 10.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0 1 12 13.489a50.702 50.702 0 0 1 7.74-3.342M6.75 15a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Zm0 0v-3.675A55.378 55.378 0 0 1 12 8.443m-7.007 11.55A5.981 5.981 0 0 0 6.75 15.75v-1.5" /></svg>)
  end

  defp document_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" /></svg>)
  end

  defp default_icon do
    ~s(<svg class="w-5 h-5 lg:w-6 lg:h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456Z" /></svg>)
  end

  defp get_initials(nil, email) do
    email
    |> String.first()
    |> String.upcase()
  end

  defp get_initials(name, _email) when is_binary(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp format_relative_date(nil), do: "—"

  defp format_relative_date(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 172_800 -> "Yesterday"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
