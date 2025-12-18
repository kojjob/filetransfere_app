defmodule FiletransferWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FiletransferWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  @doc """
  Admin layout with sidebar navigation.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :page_title, :string, default: "Admin"
  slot :inner_block, required: true

  def admin(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900">
      <%!-- Sidebar --%>
      <aside class="fixed inset-y-0 left-0 w-64 bg-slate-900/80 backdrop-blur-xl border-r border-slate-700/50">
        <%!-- Logo --%>
        <div class="flex items-center gap-3 px-6 py-5 border-b border-slate-700/50">
          <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center">
            <.icon name="hero-paper-airplane" class="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 class="text-lg font-bold text-white">ZipShare</h1>
            <p class="text-xs text-slate-400">Admin Panel</p>
          </div>
        </div>

        <%!-- Navigation --%>
        <nav class="px-4 py-6 space-y-2">
          <.admin_nav_link href="/admin/waitlist" icon="hero-users" active={true}>
            Waitlist
          </.admin_nav_link>
          <.admin_nav_link href="/admin/users" icon="hero-user-group" active={false}>
            Users
          </.admin_nav_link>
          <.admin_nav_link href="/admin/transfers" icon="hero-arrow-up-tray" active={false}>
            Transfers
          </.admin_nav_link>
          <.admin_nav_link href="/admin/analytics" icon="hero-chart-bar" active={false}>
            Analytics
          </.admin_nav_link>
        </nav>

        <%!-- Bottom section --%>
        <div class="absolute bottom-0 left-0 right-0 p-4 border-t border-slate-700/50">
          <a
            href="/"
            class="flex items-center gap-2 px-4 py-2 text-slate-400 hover:text-white transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            <span class="text-sm">Back to App</span>
          </a>
        </div>
      </aside>

      <%!-- Main content --%>
      <main class="pl-64">
        <div class="p-8">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp admin_nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200",
        @active &&
          "bg-gradient-to-r from-indigo-500/20 to-purple-500/20 text-white border border-indigo-500/30",
        !@active && "text-slate-400 hover:text-white hover:bg-slate-800/50"
      ]}
    >
      <.icon name={@icon} class="w-5 h-5" />
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc """
  User dashboard layout with sidebar navigation.
  For regular authenticated users to manage their file transfers.

  This layout is used via `layout: {FiletransferWeb.Layouts, :user_dashboard}` in LiveView mount,
  which passes content as `@inner_content` (not a slot).
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_user, :map, default: nil
  attr :page_title, :string, default: "Dashboard"
  attr :active_tab, :string, default: "dashboard"

  def user_dashboard(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-white to-slate-100 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900">
      <%!-- Sidebar --%>
      <aside class="fixed inset-y-0 left-0 w-64 bg-white/80 dark:bg-slate-900/80 backdrop-blur-xl border-r border-slate-200 dark:border-slate-700/50">
        <%!-- Logo --%>
        <div class="flex items-center gap-3 px-6 py-5 border-b border-slate-200 dark:border-slate-700/50">
          <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500 to-cyan-600 flex items-center justify-center">
            <.icon name="hero-paper-airplane" class="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 class="text-lg font-bold text-slate-900 dark:text-white">ZipShare</h1>
            <p class="text-xs text-slate-500 dark:text-slate-400">File Transfer</p>
          </div>
        </div>

        <%!-- Navigation --%>
        <nav class="px-4 py-6 space-y-2">
          <.dashboard_nav_link href="/dashboard" icon="hero-home" active={@active_tab == "dashboard"}>
            Dashboard
          </.dashboard_nav_link>
          <.dashboard_nav_link
            href="/dashboard/transfers"
            icon="hero-arrow-up-tray"
            active={@active_tab == "transfers"}
          >
            Transfers
          </.dashboard_nav_link>
          <.dashboard_nav_link
            href="/dashboard/shares"
            icon="hero-share"
            active={@active_tab == "shares"}
          >
            Shared Links
          </.dashboard_nav_link>
          <.dashboard_nav_link
            href="/dashboard/settings"
            icon="hero-cog-6-tooth"
            active={@active_tab == "settings"}
          >
            Settings
          </.dashboard_nav_link>
        </nav>

        <%!-- User info & logout --%>
        <div class="absolute bottom-0 left-0 right-0 p-4 border-t border-slate-200 dark:border-slate-700/50">
          <div class="flex items-center gap-3 px-2 py-2 mb-2">
            <div class="w-8 h-8 rounded-full bg-gradient-to-br from-blue-500 to-cyan-600 flex items-center justify-center">
              <span class="text-xs font-bold text-white">
                {if @current_user, do: String.first(@current_user.email) |> String.upcase(), else: "U"}
              </span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                {if @current_user, do: @current_user.name || @current_user.email, else: "User"}
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                {if @current_user,
                  do: String.capitalize(@current_user.subscription_tier || "free"),
                  else: "Free"} Plan
              </p>
            </div>
          </div>
          <a
            href="/api/auth/logout"
            class="flex items-center gap-2 px-4 py-2 text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white transition-colors"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" />
            <span class="text-sm">Sign out</span>
          </a>
        </div>
      </aside>

      <%!-- Main content --%>
      <main class="pl-64">
        <div class="p-8">
          {@inner_content}
        </div>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Project Owner dashboard layout with sidebar navigation.
  For project owners to manage the platform.

  This layout is used via `layout: {FiletransferWeb.Layouts, :owner_dashboard}` in LiveView mount,
  which passes content as `@inner_content` (not a slot).
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_user, :map, default: nil
  attr :page_title, :string, default: "Owner Dashboard"
  attr :active_tab, :string, default: "overview"

  def owner_dashboard(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0a0a0b] dark:bg-[#0a0a0b] [[data-theme=light]_&]:bg-[#faf9f7]">
      <%!-- Sidebar --%>
      <aside class="obsidian-sidebar fixed inset-y-0 left-0 w-60 flex flex-col">
        <%!-- Logo --%>
        <div class="flex items-center gap-3 px-5 py-4">
          <div class="obsidian-avatar-ring">
            <div class="w-8 h-8 rounded-full bg-[#0a0a0b] [[data-theme=light]_&]:bg-white flex items-center justify-center">
              <.icon name="hero-bolt" class="w-4 h-4 obsidian-accent-amber" />
            </div>
          </div>
          <div>
            <h1 class="text-sm font-semibold obsidian-text-primary tracking-tight">ZipShare</h1>
            <p class="text-[11px] obsidian-text-tertiary uppercase tracking-wider">Owner</p>
          </div>
        </div>

        <%!-- Navigation --%>
        <nav class="flex-1 px-3 py-4 space-y-1">
          <.obsidian_nav_link href="/owner" icon="hero-squares-2x2" active={@active_tab == "overview"}>
            Overview
          </.obsidian_nav_link>
          <.obsidian_nav_link href="/owner/users" icon="hero-users" active={@active_tab == "users"}>
            Users
          </.obsidian_nav_link>
          <.obsidian_nav_link href="/owner/analytics" icon="hero-chart-bar" active={@active_tab == "analytics"}>
            Analytics
          </.obsidian_nav_link>
          <.obsidian_nav_link href="/owner/settings" icon="hero-cog-6-tooth" active={@active_tab == "settings"}>
            Settings
          </.obsidian_nav_link>
        </nav>

        <%!-- Divider with label --%>
        <div class="px-5">
          <div class="obsidian-divider"></div>
        </div>

        <%!-- Quick Links --%>
        <nav class="px-3 py-4 space-y-1">
          <p class="px-3 mb-2 text-[10px] font-medium obsidian-text-tertiary uppercase tracking-widest">
            Switch View
          </p>
          <.obsidian_nav_link href="/dashboard" icon="hero-home" active={false}>
            Dashboard
          </.obsidian_nav_link>
          <.obsidian_nav_link href="/admin/waitlist" icon="hero-clipboard-document-list" active={false}>
            Admin
          </.obsidian_nav_link>
        </nav>

        <%!-- User section --%>
        <div class="p-3 mt-auto">
          <div class="obsidian-card rounded-xl p-3">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-amber-500/20 to-orange-500/20 flex items-center justify-center">
                <span class="text-xs font-semibold obsidian-accent-amber">
                  {if @current_user, do: String.first(@current_user.email) |> String.upcase(), else: "O"}
                </span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium obsidian-text-primary truncate">
                  {if @current_user, do: @current_user.name || @current_user.email, else: "Owner"}
                </p>
                <div class="flex items-center gap-1.5">
                  <span class="obsidian-live-dot"></span>
                  <span class="text-[11px] obsidian-text-tertiary">Online</span>
                </div>
              </div>
            </div>
            <a
              href="/api/auth/logout"
              class="flex items-center justify-center gap-2 mt-3 py-2 rounded-lg obsidian-text-secondary hover:obsidian-text-primary transition-colors hover:bg-white/5 [[data-theme=light]_&]:hover:bg-black/5"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" />
              <span class="text-xs font-medium">Sign out</span>
            </a>
          </div>
        </div>
      </aside>

      <%!-- Main content --%>
      <main class="pl-60">
        <%!-- Top bar with theme toggle --%>
        <header class="sticky top-0 z-10 flex items-center justify-between px-8 py-4 bg-[#0a0a0b]/80 [[data-theme=light]_&]:bg-[#faf9f7]/80 backdrop-blur-xl border-b border-white/5 [[data-theme=light]_&]:border-black/5">
          <div class="flex items-center gap-3">
            <h2 class="text-lg font-semibold obsidian-text-primary">{@page_title}</h2>
          </div>
          <div class="flex items-center gap-3">
            <.theme_toggle />
          </div>
        </header>

        <div class="p-8">
          {@inner_content}
        </div>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  # Navigation link components

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp dashboard_nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200",
        @active &&
          "bg-gradient-to-r from-blue-500/20 to-cyan-500/20 text-blue-600 dark:text-blue-400 border border-blue-500/30",
        !@active &&
          "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800/50"
      ]}
    >
      <.icon name={@icon} class="w-5 h-5" />
      {render_slot(@inner_block)}
    </a>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp owner_nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-200",
        @active &&
          "bg-gradient-to-r from-purple-500/20 to-pink-500/20 text-white border border-purple-500/30",
        !@active && "text-purple-300 hover:text-white hover:bg-purple-500/10"
      ]}
    >
      <.icon name={@icon} class="w-5 h-5" />
      {render_slot(@inner_block)}
    </a>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp obsidian_nav_link(assigns) do
    ~H"""
    <a href={@href} class={["obsidian-nav-link", @active && "active"]}>
      <.icon name={@icon} class="w-[18px] h-[18px]" />
      <span>{render_slot(@inner_block)}</span>
    </a>
    """
  end

  @doc """
  Auth layout for login and registration pages.
  Clean, minimal layout optimized for authentication flows.

  This layout is used via `layout: {FiletransferWeb.Layouts, :auth}` in LiveView mount,
  which passes content as `@inner_content` (not a slot).
  """
  def auth(assigns) do
    ~H"""
    <div class="min-h-screen">
      {@inner_content}
      <.flash_group flash={@flash} />
    </div>
    """
  end
end
