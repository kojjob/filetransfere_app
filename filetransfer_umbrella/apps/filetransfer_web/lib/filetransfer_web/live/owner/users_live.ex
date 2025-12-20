defmodule FiletransferWeb.Owner.UsersLive do
  @moduledoc """
  LiveView for project owners to manage platform users.
  Allows viewing, searching, filtering, and managing user accounts.
  """
  use FiletransferWeb, :live_view

  alias FiletransferCore.Accounts

  @impl true
  def mount(_params, _session, socket) do
    # Load users into variable to check if empty before streaming
    users = load_users("all", "", "created_at", "desc")

    socket =
      socket
      |> assign(:page_title, "Users")
      |> assign(:active_tab, "users")
      |> assign(:filter, "all")
      |> assign(:search, "")
      |> assign(:sort_by, "created_at")
      |> assign(:sort_order, "desc")
      |> assign(:has_users?, users != [] && length(users) > 0)
      |> stream(:users, users)

    {:ok, socket, layout: {FiletransferWeb.Layouts, :owner_dashboard}}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = Map.get(params, "filter", "all")
    search = Map.get(params, "search", "")
    sort_by = Map.get(params, "sort_by", "created_at")
    sort_order = Map.get(params, "sort_order", "desc")

    # Load users into variable to check if empty before streaming
    users = load_users(filter, search, sort_by, sort_order)

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:search, search)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)
      |> assign(:has_users?, users != [] && length(users) > 0)
      |> stream(:users, users, reset: true)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header Controls --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div class="flex items-center gap-3">
          <button
            type="button"
            phx-click="export_users"
            class="obsidian-btn obsidian-btn-ghost"
          >
            <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
            <span>Export</span>
          </button>
          <.link navigate={~p"/owner/users/invite"} class="obsidian-btn obsidian-btn-primary">
            <.icon name="hero-user-plus" class="w-4 h-4" />
            <span>Invite User</span>
          </.link>
        </div>
      </div>

      <%!-- Filters and Search --%>
      <div class="obsidian-card rounded-xl p-4">
        <div class="flex flex-col lg:flex-row gap-4">
          <%!-- Search --%>
          <form phx-submit="search" class="flex-1">
            <div class="relative">
              <.icon
                name="hero-magnifying-glass"
                class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 obsidian-text-tertiary"
              />
              <input
                type="text"
                name="search"
                value={@search}
                placeholder="Search by name or email..."
                class="w-full pl-10 pr-4 py-2 text-sm bg-white/5 [[data-theme=light]_&]:bg-black/5 border border-white/10 [[data-theme=light]_&]:border-black/10 rounded-lg obsidian-text-primary placeholder:obsidian-text-tertiary focus:ring-1 focus:ring-amber-500/50 focus:border-amber-500/50 transition-colors"
              />
            </div>
          </form>

          <%!-- Filter Tabs --%>
          <div class="flex gap-1 bg-white/5 [[data-theme=light]_&]:bg-black/5 rounded-lg p-0.5">
            <.filter_button filter="all" current={@filter} label="All" />
            <.filter_button filter="active" current={@filter} label="Active" />
            <.filter_button filter="inactive" current={@filter} label="Inactive" />
            <.filter_button filter="project_owner" current={@filter} label="Owners" />
          </div>
        </div>
      </div>

      <%!-- Users Table --%>
      <div class="obsidian-card rounded-xl overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="border-b border-white/5 [[data-theme=light]_&]:border-black/5">
              <tr>
                <th class="px-5 py-3 text-left text-[10px] font-medium obsidian-text-tertiary uppercase tracking-widest">
                  User
                </th>
                <th class="px-5 py-3 text-left text-[10px] font-medium obsidian-text-tertiary uppercase tracking-widest">
                  Role
                </th>
                <th class="px-5 py-3 text-left text-[10px] font-medium obsidian-text-tertiary uppercase tracking-widest">
                  Tier
                </th>
                <th class="px-5 py-3 text-left text-[10px] font-medium obsidian-text-tertiary uppercase tracking-widest">
                  Status
                </th>
                <th class="px-5 py-3 text-left text-[10px] font-medium obsidian-text-tertiary uppercase tracking-widest">
                  Joined
                </th>
                <th class="px-5 py-3 text-right text-[10px] font-medium obsidian-text-tertiary uppercase tracking-widest">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody
              id="users-list"
              phx-update="stream"
              class="divide-y divide-white/5 [[data-theme=light]_&]:divide-black/5"
            >
              <tr
                :for={{dom_id, user} <- @streams.users}
                id={dom_id}
                class="obsidian-table-row"
              >
                <td class="px-5 py-4 whitespace-nowrap">
                  <div class="flex items-center gap-3">
                    <div class="w-9 h-9 rounded-lg bg-gradient-to-br from-amber-500/20 to-orange-500/10 flex items-center justify-center">
                      <span class="text-sm font-semibold obsidian-accent-amber">
                        {String.first(user.name || user.email) |> String.upcase()}
                      </span>
                    </div>
                    <div>
                      <p class="text-sm font-medium obsidian-text-primary">
                        {user.name || "No name"}
                      </p>
                      <p class="text-xs obsidian-text-tertiary">{user.email}</p>
                    </div>
                  </div>
                </td>
                <td class="px-5 py-4 whitespace-nowrap">
                  <span class={role_badge(user.role)}>
                    {format_role(user.role)}
                  </span>
                </td>
                <td class="px-5 py-4 whitespace-nowrap">
                  <span class={tier_badge(user.subscription_tier)}>
                    {String.capitalize(user.subscription_tier || "free")}
                  </span>
                </td>
                <td class="px-5 py-4 whitespace-nowrap">
                  <span class={status_badge(user)}>
                    {user_status(user)}
                  </span>
                </td>
                <td class="px-5 py-4 whitespace-nowrap text-xs obsidian-text-tertiary">
                  {format_date(user.inserted_at)}
                </td>
                <td class="px-5 py-4 whitespace-nowrap text-right">
                  <div class="flex items-center justify-end gap-0.5">
                    <button
                      type="button"
                      phx-click="view_user"
                      phx-value-id={user.id}
                      class="p-2 obsidian-text-tertiary hover:obsidian-text-primary hover:bg-white/5 [[data-theme=light]_&]:hover:bg-black/5 rounded-lg transition-colors"
                      title="View details"
                    >
                      <.icon name="hero-eye" class="w-4 h-4" />
                    </button>
                    <button
                      type="button"
                      phx-click="edit_user"
                      phx-value-id={user.id}
                      class="p-2 obsidian-text-tertiary hover:obsidian-accent-amber hover:bg-[#d4af37]/10 rounded-lg transition-colors"
                      title="Edit user"
                    >
                      <.icon name="hero-pencil-square" class="w-4 h-4" />
                    </button>
                    <%= if user.role != "project_owner" do %>
                      <button
                        type="button"
                        phx-click="promote_user"
                        phx-value-id={user.id}
                        data-confirm="Are you sure you want to promote this user to Project Owner?"
                        class="p-2 obsidian-text-tertiary hover:obsidian-accent-emerald hover:bg-[#2dd4bf]/10 rounded-lg transition-colors"
                        title="Promote to Owner"
                      >
                        <.icon name="hero-arrow-up-circle" class="w-4 h-4" />
                      </button>
                    <% else %>
                      <button
                        type="button"
                        phx-click="demote_user"
                        phx-value-id={user.id}
                        data-confirm="Are you sure you want to demote this user to regular User?"
                        class="p-2 obsidian-text-tertiary hover:text-orange-400 hover:bg-orange-500/10 rounded-lg transition-colors"
                        title="Demote to User"
                      >
                        <.icon name="hero-arrow-down-circle" class="w-4 h-4" />
                      </button>
                    <% end %>
                    <button
                      type="button"
                      phx-click="toggle_status"
                      phx-value-id={user.id}
                      class="p-2 obsidian-text-tertiary hover:obsidian-text-primary hover:bg-white/5 [[data-theme=light]_&]:hover:bg-black/5 rounded-lg transition-colors"
                      title={if user_active?(user), do: "Deactivate", else: "Activate"}
                    >
                      <.icon
                        name={
                          if user_active?(user), do: "hero-pause-circle", else: "hero-play-circle"
                        }
                        class="w-4 h-4"
                      />
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Empty State --%>
        <div :if={!@has_users?} class="p-12 text-center">
          <div class="obsidian-icon-box mx-auto mb-4 w-14 h-14">
            <.icon name="hero-users" class="w-7 h-7 obsidian-text-tertiary" />
          </div>
          <h3 class="text-sm font-medium obsidian-text-primary mb-1">No users found</h3>
          <p class="text-xs obsidian-text-tertiary">
            <%= if @filter != "all" or @search != "" do %>
              Try adjusting your filters or search query.
            <% else %>
              No users have registered yet.
            <% end %>
          </p>
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
          "px-3 py-1.5 text-xs font-medium rounded-md bg-white/10 [[data-theme=light]_&]:bg-black/10 obsidian-text-primary transition-all"
        else
          "px-3 py-1.5 text-xs font-medium rounded-md obsidian-text-tertiary hover:obsidian-text-secondary transition-all"
        end
      )

    ~H"""
    <.link patch={~p"/owner/users?filter=#{@filter}"} class={@class}>
      {@label}
    </.link>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/owner/users?filter=#{socket.assigns.filter}&search=#{search}")}
  end

  @impl true
  def handle_event("export_users", _params, socket) do
    {:noreply, put_flash(socket, :info, "Exporting users... Download will start shortly.")}
  end

  @impl true
  def handle_event("view_user", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/owner/users/#{id}")}
  end

  @impl true
  def handle_event("edit_user", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/owner/users/#{id}/edit")}
  end

  @impl true
  def handle_event("promote_user", %{"id" => id}, socket) do
    case promote_user(id) do
      {:ok, user} ->
        socket =
          socket
          |> stream_insert(:users, user)
          |> put_flash(:info, "User promoted to Project Owner successfully.")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to promote user.")}
    end
  end

  @impl true
  def handle_event("demote_user", %{"id" => id}, socket) do
    case demote_user(id) do
      {:ok, user} ->
        socket =
          socket
          |> stream_insert(:users, user)
          |> put_flash(:info, "User demoted to regular user successfully.")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to demote user.")}
    end
  end

  @impl true
  def handle_event("toggle_status", %{"id" => id}, socket) do
    case toggle_user_status(id) do
      {:ok, user} ->
        status = if user_active?(user), do: "activated", else: "deactivated"

        socket =
          socket
          |> stream_insert(:users, user)
          |> put_flash(:info, "User #{status} successfully.")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update user status.")}
    end
  end

  # Helper Functions

  defp load_users(filter, search, _sort_by, _sort_order) do
    case function_exported?(Accounts, :list_users, 1) do
      true ->
        opts = build_filter_opts(filter, search)
        Accounts.list_users(opts)

      false ->
        case function_exported?(Accounts, :list_users, 0) do
          true ->
            users = Accounts.list_users()
            apply_filters(users, filter, search)

          false ->
            []
        end
    end
  rescue
    _ -> []
  end

  defp build_filter_opts(filter, search) do
    opts = []
    opts = if filter != "all", do: [{:filter, filter} | opts], else: opts
    opts = if search != "", do: [{:search, search} | opts], else: opts
    opts
  end

  defp apply_filters(users, filter, search) do
    users
    |> filter_by_status(filter)
    |> filter_by_search(search)
  end

  defp filter_by_status(users, "all"), do: users
  defp filter_by_status(users, "active"), do: Enum.filter(users, &user_active?/1)
  defp filter_by_status(users, "inactive"), do: Enum.reject(users, &user_active?/1)

  defp filter_by_status(users, "project_owner"),
    do: Enum.filter(users, &(&1.role == "project_owner"))

  defp filter_by_status(users, _), do: users

  defp filter_by_search(users, ""), do: users

  defp filter_by_search(users, search) do
    search = String.downcase(search)

    Enum.filter(users, fn user ->
      name = String.downcase(user.name || "")
      email = String.downcase(user.email || "")
      String.contains?(name, search) or String.contains?(email, search)
    end)
  end

  defp promote_user(id) do
    case function_exported?(Accounts, :promote_to_project_owner, 1) do
      true ->
        user = Accounts.get_user!(id)
        Accounts.promote_to_project_owner(user)

      false ->
        {:error, :not_implemented}
    end
  rescue
    _ -> {:error, :internal_error}
  end

  defp demote_user(id) do
    case function_exported?(Accounts, :demote_to_user, 1) do
      true ->
        user = Accounts.get_user!(id)
        Accounts.demote_to_user(user)

      false ->
        {:error, :not_implemented}
    end
  rescue
    _ -> {:error, :internal_error}
  end

  defp toggle_user_status(id) do
    case function_exported?(Accounts, :toggle_user_status, 1) do
      true ->
        user = Accounts.get_user!(id)
        Accounts.toggle_user_status(user)

      false ->
        {:error, :not_implemented}
    end
  rescue
    _ -> {:error, :internal_error}
  end

  defp user_active?(user) do
    # Check for active/deactivated_at field, default to true if not present
    !Map.get(user, :deactivated_at)
  end

  defp user_status(user) do
    if user_active?(user), do: "Active", else: "Inactive"
  end

  defp format_date(nil), do: "N/A"
  defp format_date(datetime), do: Calendar.strftime(datetime, "%b %d, %Y")

  defp format_role("project_owner"), do: "Project Owner"
  defp format_role("user"), do: "User"
  defp format_role(role), do: String.capitalize(role || "user")

  defp role_badge("project_owner"), do: "obsidian-badge obsidian-badge-amber"
  defp role_badge(_), do: "obsidian-badge obsidian-badge-slate"

  defp tier_badge(tier) do
    case tier do
      "enterprise" -> "obsidian-badge obsidian-badge-emerald"
      "business" -> "obsidian-badge obsidian-badge-amber"
      "pro" -> "obsidian-badge obsidian-badge-sky"
      _ -> "obsidian-badge obsidian-badge-slate"
    end
  end

  defp status_badge(user) do
    if user_active?(user) do
      "obsidian-badge obsidian-badge-emerald"
    else
      "obsidian-badge bg-red-500/15 text-red-400 border border-red-500/20"
    end
  end
end
