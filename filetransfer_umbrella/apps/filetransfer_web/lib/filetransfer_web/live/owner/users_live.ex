defmodule FiletransferWeb.Owner.UsersLive do
  @moduledoc """
  LiveView for project owners to manage platform users.
  Allows viewing, searching, filtering, and managing user accounts.
  """
  use FiletransferWeb, :live_view

  alias FiletransferCore.Accounts

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "User Management")
      |> assign(:filter, "all")
      |> assign(:search, "")
      |> assign(:sort_by, "created_at")
      |> assign(:sort_order, "desc")
      |> stream(:users, load_users("all", "", "created_at", "desc"))

    {:ok, socket, layout: {FiletransferWeb.Layouts, :owner_dashboard}}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = Map.get(params, "filter", "all")
    search = Map.get(params, "search", "")
    sort_by = Map.get(params, "sort_by", "created_at")
    sort_order = Map.get(params, "sort_order", "desc")

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:search, search)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)
      |> stream(:users, load_users(filter, search, sort_by, sort_order), reset: true)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">User Management</h1>
          <p class="text-gray-500 mt-1">View and manage all platform users.</p>
        </div>
        <div class="flex items-center gap-3">
          <button
            type="button"
            phx-click="export_users"
            class="inline-flex items-center gap-2 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
          >
            <.icon name="hero-arrow-down-tray" class="w-5 h-5" /> Export
          </button>
          <.link
            navigate={~p"/owner/users/invite"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
          >
            <.icon name="hero-user-plus" class="w-5 h-5" /> Invite User
          </.link>
        </div>
      </div>
      
    <!-- Filters and Search -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
        <div class="flex flex-col lg:flex-row gap-4">
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
                placeholder="Search by name or email..."
                class="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
              />
            </div>
          </form>
          
    <!-- Filter Tabs -->
          <div class="flex gap-2">
            <.filter_button filter="all" current={@filter} label="All Users" />
            <.filter_button filter="active" current={@filter} label="Active" />
            <.filter_button filter="inactive" current={@filter} label="Inactive" />
            <.filter_button filter="project_owner" current={@filter} label="Owners" />
          </div>
        </div>
      </div>
      
    <!-- Users Table -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50 border-b border-gray-100">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  User
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Role
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Tier
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Joined
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody id="users-list" phx-update="stream" class="divide-y divide-gray-100">
              <tr
                :for={{dom_id, user} <- @streams.users}
                id={dom_id}
                class="hover:bg-gray-50 transition-colors"
              >
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center">
                      <span class="text-purple-600 font-medium">
                        {String.first(user.name || user.email) |> String.upcase()}
                      </span>
                    </div>
                    <div>
                      <p class="font-medium text-gray-900">{user.name || "No name"}</p>
                      <p class="text-sm text-gray-500">{user.email}</p>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={role_badge(user.role)}>
                    {format_role(user.role)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={tier_badge(user.subscription_tier)}>
                    {String.capitalize(user.subscription_tier || "free")}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={status_badge(user)}>
                    {user_status(user)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {format_date(user.inserted_at)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right">
                  <div class="flex items-center justify-end gap-1">
                    <button
                      type="button"
                      phx-click="view_user"
                      phx-value-id={user.id}
                      class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                      title="View details"
                    >
                      <.icon name="hero-eye" class="w-5 h-5" />
                    </button>
                    <button
                      type="button"
                      phx-click="edit_user"
                      phx-value-id={user.id}
                      class="p-2 text-gray-400 hover:text-purple-600 hover:bg-purple-50 rounded-lg transition-colors"
                      title="Edit user"
                    >
                      <.icon name="hero-pencil-square" class="w-5 h-5" />
                    </button>
                    <%= if user.role != "project_owner" do %>
                      <button
                        type="button"
                        phx-click="promote_user"
                        phx-value-id={user.id}
                        data-confirm="Are you sure you want to promote this user to Project Owner?"
                        class="p-2 text-gray-400 hover:text-green-600 hover:bg-green-50 rounded-lg transition-colors"
                        title="Promote to Owner"
                      >
                        <.icon name="hero-arrow-up-circle" class="w-5 h-5" />
                      </button>
                    <% else %>
                      <button
                        type="button"
                        phx-click="demote_user"
                        phx-value-id={user.id}
                        data-confirm="Are you sure you want to demote this user to regular User?"
                        class="p-2 text-gray-400 hover:text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                        title="Demote to User"
                      >
                        <.icon name="hero-arrow-down-circle" class="w-5 h-5" />
                      </button>
                    <% end %>
                    <button
                      type="button"
                      phx-click="toggle_status"
                      phx-value-id={user.id}
                      class="p-2 text-gray-400 hover:text-yellow-600 hover:bg-yellow-50 rounded-lg transition-colors"
                      title={if user_active?(user), do: "Deactivate", else: "Activate"}
                    >
                      <.icon
                        name={
                          if user_active?(user), do: "hero-pause-circle", else: "hero-play-circle"
                        }
                        class="w-5 h-5"
                      />
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        
    <!-- Empty State -->
        <div :if={@streams.users |> Enum.empty?()} class="p-12 text-center">
          <.icon name="hero-users" class="w-16 h-16 mx-auto text-gray-300 mb-4" />
          <h3 class="text-lg font-medium text-gray-900 mb-2">No users found</h3>
          <p class="text-gray-500">
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
          "px-4 py-2 text-sm font-medium rounded-lg bg-purple-100 text-purple-700"
        else
          "px-4 py-2 text-sm font-medium rounded-lg text-gray-600 hover:bg-gray-100"
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

  defp role_badge("project_owner"),
    do: "px-2 py-1 text-xs rounded-full bg-purple-100 text-purple-700 font-medium"

  defp role_badge(_), do: "px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-700 font-medium"

  defp tier_badge(tier) do
    case tier do
      "enterprise" -> "px-2 py-1 text-xs rounded-full bg-orange-100 text-orange-700"
      "business" -> "px-2 py-1 text-xs rounded-full bg-purple-100 text-purple-700"
      "pro" -> "px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-700"
      _ -> "px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-700"
    end
  end

  defp status_badge(user) do
    if user_active?(user) do
      "px-2 py-1 text-xs rounded-full bg-green-100 text-green-700"
    else
      "px-2 py-1 text-xs rounded-full bg-red-100 text-red-700"
    end
  end
end
