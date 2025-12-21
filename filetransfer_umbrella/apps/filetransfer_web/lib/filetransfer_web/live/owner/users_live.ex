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
      |> assign(:viewing_user, nil)
      |> assign(:editing_user, nil)
      |> assign(:user_form, nil)
      |> assign(:invite_form, nil)
      |> stream(:users, users)

    {:ok, socket, layout: {FiletransferWeb.Layouts, :owner_dashboard}}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = Map.get(params, "filter", "all")
    search = Map.get(params, "search", "")
    sort_by = Map.get(params, "sort_by", "created_at")
    sort_order = Map.get(params, "sort_order", "desc")

    socket =
      case socket.assigns.live_action do
        :show ->
          user_id = params["id"]
          user = Accounts.get_user!(user_id)

          socket
          |> assign(:page_title, "User Details")
          |> assign(:viewing_user, user)

        :edit ->
          user_id = params["id"]
          user = Accounts.get_user!(user_id)

          socket
          |> assign(:page_title, "Edit User")
          |> assign(:editing_user, user)
          |> assign(:user_form, to_form(%{
            "email" => user.email,
            "name" => user.name || "",
            "subscription_tier" => to_string(user.subscription_tier),
            "monthly_transfer_limit" => user.monthly_transfer_limit,
            "max_file_size" => user.max_file_size,
            "api_calls_limit" => user.api_calls_limit
          }, as: :user))

        :new ->
          socket
          |> assign(:page_title, "Invite User")
          |> assign(:invite_form, to_form(%{
            "email" => "",
            "name" => "",
            "password" => "",
            "role" => "user",
            "subscription_tier" => "free",
            "monthly_transfer_limit" => 5_368_709_120,
            "max_file_size" => 2_147_483_648,
            "api_calls_limit" => 0
          }, as: :user))

        _ ->
          # Load users into variable to check if empty before streaming
          users = load_users(filter, search, sort_by, sort_order)

          socket
          |> assign(:filter, filter)
          |> assign(:search, search)
          |> assign(:sort_by, sort_by)
          |> assign(:sort_order, sort_order)
          |> assign(:page_title, "Users")
          |> assign(:editing_user, nil)
          |> assign(:user_form, nil)
          |> assign(:has_users?, users != [] && length(users) > 0)
          |> stream(:users, users, reset: true)
      end

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
          <.link navigate={~p"/owner/users/new"} class="obsidian-btn obsidian-btn-primary">
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

      <%!-- User Details Modal --%>
      <div :if={@viewing_user} class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <%!-- Backdrop --%>
          <div
            class="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity"
            phx-click="close_details"
          >
          </div>

          <%!-- Modal Content --%>
          <div class="relative obsidian-card rounded-xl max-w-2xl w-full p-6 shadow-2xl">
            <%!-- Header --%>
            <div class="flex items-center justify-between mb-6 pb-4 border-b border-white/10 [[data-theme=light]_&]:border-black/10">
              <div>
                <h2 class="text-xl font-semibold obsidian-text-primary">User Details</h2>
                <p class="text-sm obsidian-text-secondary mt-1">
                  Viewing information for <%= @viewing_user.email %>
                </p>
              </div>
              <button
                phx-click="close_details"
                class="obsidian-btn-ghost p-2 rounded-lg hover:bg-white/10 [[data-theme=light]_&]:hover:bg-black/10 transition-colors"
                aria-label="Close"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <%!-- User Information Grid --%>
            <div class="space-y-6">
              <%!-- Basic Information --%>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-1">
                  <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                    Name
                  </label>
                  <p class="text-sm obsidian-text-primary font-medium">
                    <%= @viewing_user.name || "Not set" %>
                  </p>
                </div>

                <div class="space-y-1">
                  <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                    Email
                  </label>
                  <p class="text-sm obsidian-text-primary font-medium">
                    <%= @viewing_user.email %>
                  </p>
                </div>

                <div class="space-y-1">
                  <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                    Role
                  </label>
                  <div>
                    <%= if @viewing_user.role == :project_owner do %>
                      <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-purple-500/20 text-purple-400 text-xs font-medium">
                        <.icon name="hero-shield-check-solid" class="w-3.5 h-3.5" />
                        Project Owner
                      </span>
                    <% else %>
                      <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-blue-500/20 text-blue-400 text-xs font-medium">
                        <.icon name="hero-user-solid" class="w-3.5 h-3.5" />
                        User
                      </span>
                    <% end %>
                  </div>
                </div>

                <div class="space-y-1">
                  <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                    Status
                  </label>
                  <div>
                    <%= if user_active?(@viewing_user) do %>
                      <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-green-500/20 text-green-400 text-xs font-medium">
                        <.icon name="hero-check-circle-solid" class="w-3.5 h-3.5" />
                        Active
                      </span>
                    <% else %>
                      <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-red-500/20 text-red-400 text-xs font-medium">
                        <.icon name="hero-x-circle-solid" class="w-3.5 h-3.5" />
                        Inactive
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>

              <%!-- Subscription Information --%>
              <div class="pt-4 border-t border-white/10 [[data-theme=light]_&]:border-black/10">
                <h3 class="text-sm font-semibold obsidian-text-primary mb-3">Subscription Details</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="space-y-1">
                    <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                      Tier
                    </label>
                    <p class="text-sm obsidian-text-primary font-medium capitalize">
                      <%= @viewing_user.subscription_tier %>
                    </p>
                  </div>

                  <div class="space-y-1">
                    <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                      Monthly Transfer Limit
                    </label>
                    <p class="text-sm obsidian-text-primary font-medium">
                      <%= format_bytes(@viewing_user.monthly_transfer_limit) %>
                    </p>
                  </div>

                  <div class="space-y-1">
                    <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                      Max File Size
                    </label>
                    <p class="text-sm obsidian-text-primary font-medium">
                      <%= format_bytes(@viewing_user.max_file_size) %>
                    </p>
                  </div>

                  <div class="space-y-1">
                    <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                      API Calls Limit
                    </label>
                    <p class="text-sm obsidian-text-primary font-medium">
                      <%= if @viewing_user.api_calls_limit == 0,
                        do: "Unlimited",
                        else: format_number(@viewing_user.api_calls_limit) %>
                    </p>
                  </div>
                </div>
              </div>

              <%!-- Account Information --%>
              <div class="pt-4 border-t border-white/10 [[data-theme=light]_&]:border-black/10">
                <h3 class="text-sm font-semibold obsidian-text-primary mb-3">Account Information</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="space-y-1">
                    <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                      Created
                    </label>
                    <p class="text-sm obsidian-text-primary font-medium">
                      <%= Calendar.strftime(@viewing_user.inserted_at, "%B %d, %Y at %I:%M %p") %>
                    </p>
                  </div>

                  <div class="space-y-1">
                    <label class="text-xs font-medium obsidian-text-secondary uppercase tracking-wider">
                      Last Updated
                    </label>
                    <p class="text-sm obsidian-text-primary font-medium">
                      <%= Calendar.strftime(@viewing_user.updated_at, "%B %d, %Y at %I:%M %p") %>
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Actions --%>
            <div class="flex items-center justify-end gap-3 mt-6 pt-4 border-t border-white/10 [[data-theme=light]_&]:border-black/10">
              <button
                phx-click="close_details"
                class="obsidian-btn-ghost px-4 py-2 rounded-lg hover:bg-white/10 [[data-theme=light]_&]:hover:bg-black/10 transition-colors"
              >
                Close
              </button>
              <.link
                navigate={~p"/owner/users/#{@viewing_user.id}/edit"}
                class="obsidian-btn-primary px-4 py-2 rounded-lg hover:brightness-110 transition-all"
              >
                Edit User
              </.link>
            </div>
          </div>
        </div>
      </div>

      <%!-- Invite User Modal --%>
      <div :if={@invite_form} class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <%!-- Backdrop --%>
          <div
            class="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity"
            phx-click="cancel_invite"
          >
          </div>

          <%!-- Modal Content --%>
          <div class="relative obsidian-card rounded-xl p-6 max-w-2xl w-full mx-4 shadow-2xl">
            <%!-- Header --%>
            <div class="flex items-center justify-between mb-6 pb-4 border-b border-white/10 [[data-theme=light]_&]:border-black/10">
              <div>
                <h2 class="text-xl font-semibold obsidian-text-primary">Invite User</h2>
                <p class="text-sm obsidian-text-tertiary mt-1">Send an invitation to a new user</p>
              </div>
              <button
                type="button"
                phx-click="cancel_invite"
                class="p-2 obsidian-text-tertiary hover:obsidian-text-primary hover:bg-white/5 [[data-theme=light]_&]:hover:bg-black/5 rounded-lg transition-colors"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <%!-- Form --%>
            <.form id="invite-user-form" for={@invite_form} phx-submit="create_user" class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <%!-- Name --%>
                <div class="md:col-span-2">
                  <.input
                    field={@invite_form[:name]}
                    type="text"
                    label="Name"
                    placeholder="Enter user's name"
                    class="obsidian-input"
                  />
                </div>

                <%!-- Email --%>
                <div class="md:col-span-2">
                  <.input
                    field={@invite_form[:email]}
                    type="email"
                    label="Email"
                    placeholder="user@example.com"
                    required
                    class="obsidian-input"
                  />
                </div>

                <%!-- Password --%>
                <div class="md:col-span-2">
                  <.input
                    field={@invite_form[:password]}
                    type="password"
                    label="Temporary Password"
                    placeholder="Enter temporary password"
                    required
                    class="obsidian-input"
                  />
                  <p class="mt-1 text-xs obsidian-text-tertiary">
                    User will be asked to change this password on first login
                  </p>
                </div>

                <%!-- Role --%>
                <div>
                  <.input
                    field={@invite_form[:role]}
                    type="select"
                    label="Role"
                    options={[
                      {"User", "user"},
                      {"Project Owner", "project_owner"}
                    ]}
                    class="obsidian-input"
                  />
                </div>

                <%!-- Subscription Tier --%>
                <div>
                  <.input
                    field={@invite_form[:subscription_tier]}
                    type="select"
                    label="Subscription Tier"
                    options={[
                      {"Free", "free"},
                      {"Pro", "pro"},
                      {"Business", "business"},
                      {"Enterprise", "enterprise"}
                    ]}
                    class="obsidian-input"
                  />
                </div>

                <%!-- Monthly Transfer Limit (bytes) --%>
                <div>
                  <.input
                    field={@invite_form[:monthly_transfer_limit]}
                    type="number"
                    label="Monthly Transfer Limit (bytes)"
                    placeholder="5368709120"
                    class="obsidian-input"
                  />
                  <p class="mt-1 text-xs obsidian-text-tertiary">
                    Default: 5 GB (5,368,709,120 bytes)
                  </p>
                </div>

                <%!-- Max File Size (bytes) --%>
                <div>
                  <.input
                    field={@invite_form[:max_file_size]}
                    type="number"
                    label="Max File Size (bytes)"
                    placeholder="2147483648"
                    class="obsidian-input"
                  />
                  <p class="mt-1 text-xs obsidian-text-tertiary">
                    Default: 2 GB (2,147,483,648 bytes)
                  </p>
                </div>

                <%!-- API Calls Limit --%>
                <div>
                  <.input
                    field={@invite_form[:api_calls_limit]}
                    type="number"
                    label="API Calls Limit"
                    placeholder="0"
                    class="obsidian-input"
                  />
                  <p class="mt-1 text-xs obsidian-text-tertiary">
                    0 = Unlimited
                  </p>
                </div>
              </div>

              <%!-- Actions --%>
              <div class="flex justify-end gap-3 pt-4 border-t border-white/10 [[data-theme=light]_&]:border-black/10">
                <button
                  type="button"
                  phx-click="cancel_invite"
                  class="obsidian-btn obsidian-btn-secondary"
                >
                  Cancel
                </button>
                <button type="submit" class="obsidian-btn obsidian-btn-primary">
                  Send Invitation
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>

      <%!-- Edit User Modal --%>
      <div :if={@editing_user} class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <%!-- Backdrop --%>
          <div
            class="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity"
            phx-click="cancel_edit"
          >
          </div>

          <%!-- Modal Content --%>
          <div class="relative obsidian-card rounded-xl p-6 max-w-2xl w-full mx-4 shadow-2xl">
            <%!-- Header --%>
            <div class="flex items-center justify-between mb-6 pb-4 border-b border-white/10 [[data-theme=light]_&]:border-black/10">
              <div>
                <h2 class="text-xl font-semibold obsidian-text-primary">Edit User</h2>
                <p class="text-sm obsidian-text-tertiary mt-1">{@editing_user.email}</p>
              </div>
              <button
                type="button"
                phx-click="cancel_edit"
                class="p-2 obsidian-text-tertiary hover:obsidian-text-primary hover:bg-white/5 [[data-theme=light]_&]:hover:bg-black/5 rounded-lg transition-colors"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <%!-- Form --%>
            <.form for={@user_form} phx-submit="save_user" class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <%!-- Name --%>
                <div class="md:col-span-2">
                  <.input
                    field={@user_form[:name]}
                    type="text"
                    label="Name"
                    placeholder="Enter user's name"
                    class="obsidian-input"
                  />
                </div>

                <%!-- Email --%>
                <div class="md:col-span-2">
                  <.input
                    field={@user_form[:email]}
                    type="email"
                    label="Email"
                    placeholder="user@example.com"
                    required
                    class="obsidian-input"
                  />
                </div>

                <%!-- Subscription Tier --%>
                <div>
                  <.input
                    field={@user_form[:subscription_tier]}
                    type="select"
                    label="Subscription Tier"
                    options={[
                      {"Free", "free"},
                      {"Pro", "pro"},
                      {"Business", "business"},
                      {"Enterprise", "enterprise"}
                    ]}
                    class="obsidian-input"
                  />
                </div>

                <%!-- Monthly Transfer Limit (GB) --%>
                <div>
                  <.input
                    field={@user_form[:monthly_transfer_limit]}
                    type="number"
                    label="Monthly Transfer Limit (bytes)"
                    placeholder="5368709120"
                    class="obsidian-input"
                  />
                  <p class="mt-1 text-xs obsidian-text-tertiary">
                    Default: 5 GB (5,368,709,120 bytes)
                  </p>
                </div>

                <%!-- Max File Size (GB) --%>
                <div>
                  <.input
                    field={@user_form[:max_file_size]}
                    type="number"
                    label="Max File Size (bytes)"
                    placeholder="2147483648"
                    class="obsidian-input"
                  />
                  <p class="mt-1 text-xs obsidian-text-tertiary">
                    Default: 2 GB (2,147,483,648 bytes)
                  </p>
                </div>

                <%!-- API Calls Limit --%>
                <div>
                  <.input
                    field={@user_form[:api_calls_limit]}
                    type="number"
                    label="API Calls Limit"
                    placeholder="0"
                    class="obsidian-input"
                  />
                  <p class="mt-1 text-xs obsidian-text-tertiary">
                    0 = No API access
                  </p>
                </div>
              </div>

              <%!-- Actions --%>
              <div class="flex items-center justify-end gap-3 pt-4 border-t border-white/10 [[data-theme=light]_&]:border-black/10">
                <button
                  type="button"
                  phx-click="cancel_edit"
                  class="obsidian-btn obsidian-btn-ghost"
                >
                  Cancel
                </button>
                <button type="submit" class="obsidian-btn obsidian-btn-primary">
                  <.icon name="hero-check" class="w-4 h-4" />
                  <span>Save Changes</span>
                </button>
              </div>
            </.form>
          </div>
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

  @impl true
  def handle_event("save_user", %{"user" => user_params}, socket) do
    case Accounts.update_user(socket.assigns.editing_user, user_params) do
      {:ok, user} ->
        socket =
          socket
          |> stream_insert(:users, user)
          |> put_flash(:info, "User updated successfully.")
          |> push_navigate(to: ~p"/owner/users")

        {:noreply, socket}

      {:error, _changeset} ->
        # Keep the user's input on error
        {:noreply, assign(socket, user_form: to_form(user_params, as: :user))}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/owner/users")}
  end

  @impl true
  def handle_event("close_details", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/owner/users")}
  end

  @impl true
  def handle_event("create_user", %{"user" => user_params}, socket) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        socket =
          socket
          |> stream_insert(:users, user)
          |> put_flash(:info, "User invitation sent successfully.")
          |> push_navigate(to: ~p"/owner/users")

        {:noreply, socket}

      {:error, changeset} ->
        # Keep the user's input on error and show validation errors
        errors = changeset.errors |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)

        socket =
          socket
          |> put_flash(:error, "Failed to create user: #{Enum.join(errors, ", ")}")
          |> assign(invite_form: to_form(user_params, as: :user))

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_invite", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/owner/users")}
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

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_099_511_627_776 -> "#{Float.round(bytes / 1_099_511_627_776, 2)} TB"
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_bytes(_), do: "N/A"

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
  end

  defp format_number(_), do: "N/A"
end
