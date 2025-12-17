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
      |> assign_stats()
      |> stream(:entries, Waitlist.list_waitlist_entries())

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign_stats()
     |> stream(:entries, Waitlist.list_waitlist_entries(), reset: true)}
  end

  @impl true
  def handle_event("export", _params, socket) do
    {:noreply, redirect(socket, to: "/admin/waitlist/export")}
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

    socket
    |> assign(:total_count, total)
    |> assign(:week_count, recent)
    |> assign(:today_count, today)
    |> assign(:use_cases, use_cases)
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
              FlowTransfer
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

          <%!-- Stats Grid - Responsive --%>
          <div class="grid grid-cols-2 lg:grid-cols-6 gap-3 lg:gap-4 mb-6 lg:mb-8">
            <%!-- Total - Large on desktop, normal on mobile --%>
            <div class="col-span-2 lg:row-span-2 p-4 lg:p-6 rounded-2xl lg:rounded-3xl bg-zinc-900 dark:bg-white text-white dark:text-zinc-900 relative overflow-hidden group">
              <div class="absolute -right-6 -bottom-6 lg:-right-8 lg:-bottom-8 opacity-10 group-hover:opacity-20 transition-opacity">
                <.icon name="hero-envelope" class="w-24 h-24 lg:w-32 lg:h-32" />
              </div>
              <p class="text-xs lg:text-sm font-medium text-zinc-400 dark:text-zinc-500 mb-1">
                Total Signups
              </p>
              <p class="text-4xl lg:text-6xl font-bold tracking-tight">{@total_count}</p>
              <p class="text-xs lg:text-sm text-zinc-500 dark:text-zinc-400 mt-2 lg:mt-4">All time</p>
            </div>

            <%!-- This Week --%>
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
            </div>

            <%!-- Use Cases Section --%>
            <div class="col-span-2 lg:col-span-4 p-4 lg:p-6 rounded-2xl lg:rounded-3xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800">
              <div class="flex items-center justify-between mb-4 lg:mb-5">
                <div>
                  <h3 class="font-bold text-zinc-900 dark:text-white text-sm lg:text-base">
                    What people want to use it for
                  </h3>
                  <p class="text-xs lg:text-sm text-zinc-500 dark:text-zinc-400">
                    Self-reported use cases
                  </p>
                </div>
                <div class="w-8 h-8 lg:w-10 lg:h-10 rounded-xl bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center">
                  <.icon
                    name="hero-sparkles"
                    class="w-4 h-4 lg:w-5 lg:h-5 text-purple-600 dark:text-purple-400"
                  />
                </div>
              </div>

              <%= if @use_cases == [] do %>
                <div class="flex flex-col items-center justify-center py-6 lg:py-8 text-center">
                  <.icon
                    name="hero-question-mark-circle"
                    class="w-10 h-10 lg:w-12 lg:h-12 text-zinc-300 dark:text-zinc-600 mb-3"
                  />
                  <p class="text-zinc-500 dark:text-zinc-400 text-xs lg:text-sm">
                    No one has shared their use case yet
                  </p>
                </div>
              <% else %>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 lg:gap-3">
                  <%= for {{use_case, count}, index} <- Enum.with_index(@use_cases) do %>
                    <div class={[
                      "relative p-3 lg:p-4 rounded-xl lg:rounded-2xl border-2 transition-all duration-200 hover:scale-[1.02]",
                      case index do
                        0 ->
                          "border-amber-300 dark:border-amber-600 bg-amber-50 dark:bg-amber-900/20"

                        1 ->
                          "border-zinc-300 dark:border-zinc-600 bg-zinc-50 dark:bg-zinc-800/50"

                        2 ->
                          "border-orange-300 dark:border-orange-700 bg-orange-50 dark:bg-orange-900/20"

                        _ ->
                          "border-zinc-200 dark:border-zinc-700 bg-zinc-50 dark:bg-zinc-800/30"
                      end
                    ]}>
                      <div class="flex items-start justify-between gap-2">
                        <div class="flex-1 min-w-0">
                          <p class="font-semibold text-zinc-900 dark:text-white text-sm truncate">
                            {use_case}
                          </p>
                          <p class="text-xs text-zinc-500 dark:text-zinc-400">
                            {count} {if count == 1, do: "person", else: "people"}
                          </p>
                        </div>
                        <.rank_badge index={index} />
                      </div>
                      <div class="mt-2 lg:mt-3 h-1 lg:h-1.5 bg-zinc-200 dark:bg-zinc-700 rounded-full overflow-hidden">
                        <div
                          class={[
                            "h-full rounded-full transition-all duration-500",
                            case index do
                              0 -> "bg-amber-400"
                              1 -> "bg-zinc-400"
                              2 -> "bg-orange-400"
                              _ -> "bg-zinc-300 dark:bg-zinc-500"
                            end
                          ]}
                          style={"width: #{count / max(Enum.at(@use_cases, 0) |> elem(1), 1) * 100}%"}
                        />
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Entries Table --%>
          <div class="rounded-2xl lg:rounded-3xl bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 overflow-hidden">
            <div class="px-4 lg:px-6 py-4 lg:py-5 border-b border-zinc-200 dark:border-zinc-800 flex items-center justify-between">
              <div class="flex items-center gap-2 lg:gap-3">
                <.icon name="hero-clipboard-document-list" class="w-5 h-5 text-zinc-400" />
                <h2 class="font-bold text-zinc-900 dark:text-white text-sm lg:text-base">
                  All Signups
                </h2>
              </div>
              <span class="text-xs lg:text-sm text-zinc-500 dark:text-zinc-400">
                {@total_count} total
              </span>
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
                      class="hover:bg-zinc-50 dark:hover:bg-zinc-800/50 transition-colors"
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

  # Helpers

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
