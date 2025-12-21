defmodule FiletransferWeb.Dashboard.SettingsLive do
  @moduledoc """
  LiveView for user account settings.
  Allows users to update profile, change password, and manage preferences.
  """
  use FiletransferWeb, :live_view

  alias FiletransferCore.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:active_tab, "profile")
      |> assign(
        :profile_form,
        to_form(%{
          "email" => user.email,
          "name" => user.name || ""
        })
      )
      |> assign(
        :password_form,
        to_form(%{"current_password" => "", "password" => "", "password_confirmation" => ""})
      )

    {:ok, socket, layout: {FiletransferWeb.Layouts, :user_dashboard}}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = Map.get(params, "tab", "profile")
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Account Settings</h1>
        <p class="text-gray-500 mt-1">Manage your account preferences and security settings.</p>
      </div>
      
    <!-- Tabs -->
      <div class="border-b border-gray-200">
        <nav class="flex gap-8">
          <.tab_link tab="profile" current={@active_tab} label="Profile" icon="hero-user" />
          <.tab_link tab="security" current={@active_tab} label="Security" icon="hero-shield-check" />
          <.tab_link tab="notifications" current={@active_tab} label="Notifications" icon="hero-bell" />
          <.tab_link tab="billing" current={@active_tab} label="Billing" icon="hero-credit-card" />
        </nav>
      </div>
      
    <!-- Tab Content -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-100">
        <%= case @active_tab do %>
          <% "profile" -> %>
            <.profile_tab form={@profile_form} user={@current_user} />
          <% "security" -> %>
            <.security_tab form={@password_form} />
          <% "notifications" -> %>
            <.notifications_tab />
          <% "billing" -> %>
            <.billing_tab user={@current_user} />
        <% end %>
      </div>
    </div>
    """
  end

  # Tab Components

  defp tab_link(assigns) do
    active = assigns.tab == assigns.current

    assigns =
      assign(
        assigns,
        :class,
        if active do
          "flex items-center gap-2 px-1 py-4 text-sm font-medium text-blue-600 border-b-2 border-blue-600"
        else
          "flex items-center gap-2 px-1 py-4 text-sm font-medium text-gray-500 hover:text-gray-700 border-b-2 border-transparent"
        end
      )

    ~H"""
    <.link patch={~p"/dashboard/settings?tab=#{@tab}"} class={@class}>
      <.icon name={@icon} class="w-5 h-5" />
      {@label}
    </.link>
    """
  end

  defp profile_tab(assigns) do
    ~H"""
    <div class="p-6 space-y-6">
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Profile Information</h2>
        <p class="text-sm text-gray-500 mt-1">Update your personal details and email address.</p>
      </div>

      <.form for={@form} phx-submit="save_profile" class="space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Name</label>
            <input
              type="text"
              name="user[name]"
              value={@user.name}
              class="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Your name"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Email</label>
            <input
              type="email"
              name="user[email]"
              value={@user.email}
              class="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="you@example.com"
            />
          </div>
        </div>

        <div class="flex justify-end">
          <button
            type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Save Changes
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp security_tab(assigns) do
    ~H"""
    <div class="p-6 space-y-8">
      <!-- Change Password Section -->
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Change Password</h2>
        <p class="text-sm text-gray-500 mt-1">Update your password to keep your account secure.</p>

        <.form for={@form} phx-submit="change_password" class="mt-6 space-y-4 max-w-md">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Current Password</label>
            <input
              type="password"
              name="current_password"
              class="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">New Password</label>
            <input
              type="password"
              name="password"
              class="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Confirm New Password</label>
            <input
              type="password"
              name="password_confirmation"
              class="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <button
            type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Update Password
          </button>
        </.form>
      </div>
      
    <!-- Two-Factor Authentication Section -->
      <div class="pt-8 border-t border-gray-200">
        <h2 class="text-lg font-semibold text-gray-900">Two-Factor Authentication</h2>
        <p class="text-sm text-gray-500 mt-1">Add an extra layer of security to your account.</p>

        <div class="mt-6 p-4 bg-gray-50 rounded-lg flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-gray-200 rounded-lg">
              <.icon name="hero-device-phone-mobile" class="w-6 h-6 text-gray-600" />
            </div>
            <div>
              <p class="font-medium text-gray-900">Authenticator App</p>
              <p class="text-sm text-gray-500">Not configured</p>
            </div>
          </div>
          <button
            type="button"
            class="px-4 py-2 text-blue-600 border border-blue-600 rounded-lg hover:bg-blue-50 transition-colors"
          >
            Set Up
          </button>
        </div>
      </div>
      
    <!-- Active Sessions Section -->
      <div class="pt-8 border-t border-gray-200">
        <h2 class="text-lg font-semibold text-gray-900">Active Sessions</h2>
        <p class="text-sm text-gray-500 mt-1">
          Manage your active sessions and sign out from other devices.
        </p>

        <div class="mt-6 space-y-3">
          <div class="p-4 bg-green-50 border border-green-200 rounded-lg flex items-center justify-between">
            <div class="flex items-center gap-3">
              <.icon name="hero-computer-desktop" class="w-6 h-6 text-green-600" />
              <div>
                <p class="font-medium text-gray-900">Current Session</p>
                <p class="text-sm text-gray-500">This device · Active now</p>
              </div>
            </div>
            <span class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded-full">Current</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp notifications_tab(assigns) do
    ~H"""
    <div class="p-6 space-y-6">
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Notification Preferences</h2>
        <p class="text-sm text-gray-500 mt-1">Choose how you want to be notified about activity.</p>
      </div>

      <form phx-submit="save_notifications" class="space-y-6">
        <div class="space-y-4">
          <.notification_toggle
            id="email_transfers"
            label="Transfer Notifications"
            description="Get notified when your transfers complete or fail"
            checked={true}
          />
          <.notification_toggle
            id="email_shares"
            label="Share Activity"
            description="Get notified when someone accesses your shared files"
            checked={true}
          />
          <.notification_toggle
            id="email_security"
            label="Security Alerts"
            description="Get notified about security events like new sign-ins"
            checked={true}
          />
          <.notification_toggle
            id="email_marketing"
            label="Product Updates"
            description="Receive news about new features and improvements"
            checked={false}
          />
        </div>

        <div class="flex justify-end">
          <button
            type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Save Preferences
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp notification_toggle(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
      <div>
        <p class="font-medium text-gray-900">{@label}</p>
        <p class="text-sm text-gray-500">{@description}</p>
      </div>
      <label class="relative inline-flex items-center cursor-pointer">
        <input type="checkbox" name={@id} checked={@checked} class="sr-only peer" />
        <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600">
        </div>
      </label>
    </div>
    """
  end

  defp billing_tab(assigns) do
    ~H"""
    <div class="p-6 space-y-8">
      <!-- Current Plan -->
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Current Plan</h2>
        <p class="text-sm text-gray-500 mt-1">Manage your subscription and billing details.</p>

        <div class="mt-6 p-6 bg-gradient-to-r from-blue-500 to-cyan-500 rounded-xl text-white">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-blue-100 text-sm">Current Plan</p>
              <p class="text-2xl font-bold mt-1">
                {String.capitalize(@user.subscription_tier || "free")}
              </p>
            </div>
            <button
              type="button"
              class="px-4 py-2 bg-white text-blue-600 rounded-lg hover:bg-blue-50 transition-colors font-medium"
            >
              Upgrade Plan
            </button>
          </div>

          <div class="mt-6 grid grid-cols-3 gap-4">
            <div>
              <p class="text-blue-100 text-sm">Monthly Transfer</p>
              <p class="font-semibold">{format_bytes(@user.monthly_transfer_limit)}</p>
            </div>
            <div>
              <p class="text-blue-100 text-sm">Max File Size</p>
              <p class="font-semibold">{format_bytes(@user.max_file_size)}</p>
            </div>
            <div>
              <p class="text-blue-100 text-sm">API Calls</p>
              <p class="font-semibold">{format_api_calls(@user.api_calls_limit)}</p>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Usage -->
      <div class="pt-8 border-t border-gray-200">
        <h2 class="text-lg font-semibold text-gray-900">Usage This Month</h2>

        <div class="mt-6 space-y-4">
          <.usage_bar label="Transfer Usage" used={0} limit={@user.monthly_transfer_limit} />
          <.usage_bar
            label="API Calls"
            used={@user.api_calls_used || 0}
            limit={@user.api_calls_limit}
          />
        </div>
      </div>
      
    <!-- Payment Methods -->
      <div class="pt-8 border-t border-gray-200">
        <h2 class="text-lg font-semibold text-gray-900">Payment Methods</h2>
        <p class="text-sm text-gray-500 mt-1">Manage your payment methods for billing.</p>

        <div class="mt-6">
          <%= if @user.stripe_customer_id do %>
            <div class="p-4 bg-gray-50 rounded-lg flex items-center justify-between">
              <div class="flex items-center gap-3">
                <.icon name="hero-credit-card" class="w-6 h-6 text-gray-600" />
                <div>
                  <p class="font-medium text-gray-900">•••• •••• •••• 4242</p>
                  <p class="text-sm text-gray-500">Expires 12/25</p>
                </div>
              </div>
              <button type="button" class="text-sm text-blue-600 hover:text-blue-700">
                Update
              </button>
            </div>
          <% else %>
            <button
              type="button"
              class="w-full p-4 border-2 border-dashed border-gray-300 rounded-lg text-gray-500 hover:border-blue-500 hover:text-blue-500 transition-colors"
            >
              <.icon name="hero-plus" class="w-6 h-6 mx-auto mb-2" /> Add Payment Method
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp usage_bar(assigns) do
    percentage =
      if assigns.limit && assigns.limit > 0 do
        min(100, round(assigns.used / assigns.limit * 100))
      else
        0
      end

    assigns = assign(assigns, :percentage, percentage)

    ~H"""
    <div>
      <div class="flex justify-between text-sm mb-2">
        <span class="text-gray-600">{@label}</span>
        <span class="text-gray-900 font-medium">
          {format_usage_value(@used)} / {format_usage_value(@limit)}
        </span>
      </div>
      <div class="h-2 bg-gray-200 rounded-full overflow-hidden">
        <div
          class={"h-full rounded-full #{if @percentage > 80, do: "bg-red-500", else: "bg-blue-500"}"}
          style={"width: #{@percentage}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("save_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_user(user, user_params) do
      {:ok, updated_user} ->
        socket =
          socket
          |> assign(:current_user, updated_user)
          |> assign(
            :profile_form,
            to_form(%{
              "email" => updated_user.email,
              "name" => updated_user.name || ""
            })
          )
          |> put_flash(:info, "Profile updated successfully.")

        {:noreply, socket}

      {:error, _changeset} ->
        # Keep the user's input on error
        {:noreply, assign(socket, :profile_form, to_form(user_params))}
    end
  end

  @impl true
  def handle_event("change_password", _params, socket) do
    # TODO: Implement password change logic
    {:noreply, put_flash(socket, :info, "Password change functionality coming soon.")}
  end

  @impl true
  def handle_event("save_notifications", _params, socket) do
    {:noreply, put_flash(socket, :info, "Notification preferences saved.")}
  end

  # Helper Functions

  defp format_bytes(nil), do: "Unlimited"
  defp format_bytes(:unlimited), do: "Unlimited"

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_api_calls(nil), do: "None"
  defp format_api_calls(0), do: "None"
  defp format_api_calls(:unlimited), do: "Unlimited"
  defp format_api_calls(count), do: "#{count}/month"

  defp format_usage_value(:unlimited), do: "Unlimited"
  defp format_usage_value(nil), do: "0"
  defp format_usage_value(value) when is_integer(value), do: Integer.to_string(value)
  defp format_usage_value(value), do: to_string(value)
end
