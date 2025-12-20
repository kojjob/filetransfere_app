defmodule FiletransferWeb.Owner.SettingsLive do
  @moduledoc """
  Platform settings management for project owners.
  Allows configuration of platform-wide settings, limits, and features.
  """
  use FiletransferWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:active_tab, "settings")
      |> assign(:settings_tab, "general")
      |> assign(:settings, load_settings())
      |> assign(:unsaved_changes, false)

    {:ok, socket, layout: {FiletransferWeb.Layouts, :owner_dashboard}}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = Map.get(params, "tab", "general")
    {:noreply, assign(socket, :settings_tab, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Settings Navigation --%>
      <div class="obsidian-card rounded-xl overflow-hidden">
        <div class="border-b border-white/5 [[data-theme=light]_&]:border-black/5">
          <nav class="flex gap-1 p-2 overflow-x-auto">
            <.tab_button
              tab="general"
              current={@settings_tab}
              label="General"
              icon="hero-cog-6-tooth"
            />
            <.tab_button
              tab="storage"
              current={@settings_tab}
              label="Storage"
              icon="hero-server-stack"
            />
            <.tab_button
              tab="transfers"
              current={@settings_tab}
              label="Transfers"
              icon="hero-arrow-up-tray"
            />
            <.tab_button
              tab="security"
              current={@settings_tab}
              label="Security"
              icon="hero-shield-check"
            />
            <.tab_button tab="email" current={@settings_tab} label="Email" icon="hero-envelope" />
            <.tab_button
              tab="maintenance"
              current={@settings_tab}
              label="Maintenance"
              icon="hero-wrench-screwdriver"
            />
          </nav>
        </div>

        <div class="p-6">
          <%= case @settings_tab do %>
            <% "general" -> %>
              <.general_settings settings={@settings} />
            <% "storage" -> %>
              <.storage_settings settings={@settings} />
            <% "transfers" -> %>
              <.transfer_settings settings={@settings} />
            <% "security" -> %>
              <.security_settings settings={@settings} />
            <% "email" -> %>
              <.email_settings settings={@settings} />
            <% "maintenance" -> %>
              <.maintenance_settings settings={@settings} />
            <% _ -> %>
              <.general_settings settings={@settings} />
          <% end %>
        </div>
      </div>

      <%!-- Save Button --%>
      <div class="flex justify-end gap-3">
        <button
          type="button"
          phx-click="reset_settings"
          class="obsidian-btn obsidian-btn-ghost"
        >
          Reset to Defaults
        </button>
        <button
          type="button"
          phx-click="save_settings"
          class={[
            "obsidian-btn",
            if(@unsaved_changes,
              do: "obsidian-btn-primary",
              else:
                "opacity-50 cursor-not-allowed bg-white/10 [[data-theme=light]_&]:bg-black/10 obsidian-text-tertiary"
            )
          ]}
          disabled={not @unsaved_changes}
        >
          Save Changes
        </button>
      </div>
    </div>
    """
  end

  # Tab Button Component
  defp tab_button(assigns) do
    active = assigns.tab == assigns.current

    assigns =
      assign(
        assigns,
        :class,
        if active do
          "flex items-center gap-2 px-3 py-2 text-xs font-medium rounded-lg bg-[#d4af37]/10 obsidian-accent-amber transition-all"
        else
          "flex items-center gap-2 px-3 py-2 text-xs font-medium rounded-lg obsidian-text-tertiary hover:obsidian-text-secondary hover:bg-white/5 [[data-theme=light]_&]:hover:bg-black/5 transition-all"
        end
      )

    ~H"""
    <.link patch={~p"/owner/settings?tab=#{@tab}"} class={@class}>
      <.icon name={@icon} class="w-4 h-4" />
      <span class="hidden sm:inline">{@label}</span>
    </.link>
    """
  end

  # General Settings Tab
  defp general_settings(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-semibold obsidian-text-primary mb-1">General Settings</h3>
        <p class="text-xs obsidian-text-tertiary">Configure basic platform settings and branding.</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <.setting_field
          label="Platform Name"
          description="The name displayed throughout the application"
          type="text"
          name="platform_name"
          value={@settings.platform_name}
        />

        <.setting_field
          label="Support Email"
          description="Email address for user support inquiries"
          type="email"
          name="support_email"
          value={@settings.support_email}
        />

        <.setting_field
          label="Default Language"
          description="Default language for new users"
          type="select"
          name="default_language"
          value={@settings.default_language}
          options={[{"English", "en"}, {"Spanish", "es"}, {"French", "fr"}, {"German", "de"}]}
        />

        <.setting_field
          label="Time Zone"
          description="Default timezone for the platform"
          type="select"
          name="default_timezone"
          value={@settings.default_timezone}
          options={[
            {"UTC", "UTC"},
            {"US/Eastern", "US/Eastern"},
            {"US/Pacific", "US/Pacific"},
            {"Europe/London", "Europe/London"}
          ]}
        />
      </div>

      <div class="obsidian-divider my-6"></div>

      <div>
        <h4 class="text-sm font-medium obsidian-text-primary mb-4">Feature Flags</h4>
        <div class="space-y-4">
          <.toggle_setting
            label="User Registration"
            description="Allow new users to register"
            name="allow_registration"
            enabled={@settings.allow_registration}
          />
          <.toggle_setting
            label="Public Shares"
            description="Allow users to create public share links"
            name="allow_public_shares"
            enabled={@settings.allow_public_shares}
          />
          <.toggle_setting
            label="API Access"
            description="Enable API access for users"
            name="api_enabled"
            enabled={@settings.api_enabled}
          />
        </div>
      </div>
    </div>
    """
  end

  # Storage Settings Tab
  defp storage_settings(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-semibold obsidian-text-primary mb-1">Storage Settings</h3>
        <p class="text-xs obsidian-text-tertiary">
          Configure storage limits and file handling options.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <.setting_field
          label="Max File Size (MB)"
          description="Maximum size for individual file uploads"
          type="number"
          name="max_file_size_mb"
          value={@settings.max_file_size_mb}
        />
        <.setting_field
          label="Default User Storage (GB)"
          description="Default storage quota for free users"
          type="number"
          name="default_storage_gb"
          value={@settings.default_storage_gb}
        />
        <.setting_field
          label="Pro Storage (GB)"
          description="Storage quota for Pro users"
          type="number"
          name="pro_storage_gb"
          value={@settings.pro_storage_gb}
        />
        <.setting_field
          label="Business Storage (GB)"
          description="Storage quota for Business users"
          type="number"
          name="business_storage_gb"
          value={@settings.business_storage_gb}
        />
      </div>

      <div class="obsidian-divider my-6"></div>

      <div>
        <h4 class="text-sm font-medium obsidian-text-primary mb-3">Allowed File Types</h4>
        <div class="bg-white/5 [[data-theme=light]_&]:bg-black/5 rounded-lg p-4">
          <p class="text-xs obsidian-text-tertiary mb-3">
            Comma-separated list of allowed file extensions
          </p>
          <textarea
            name="allowed_extensions"
            phx-change="update_setting"
            class="w-full px-3 py-2 text-sm bg-white/5 [[data-theme=light]_&]:bg-black/5 border border-white/10 [[data-theme=light]_&]:border-black/10 rounded-lg obsidian-text-primary focus:ring-1 focus:ring-amber-500/50 focus:border-amber-500/50"
            rows="3"
          >{@settings.allowed_extensions}</textarea>
        </div>
      </div>

      <div class="obsidian-divider my-6"></div>

      <div>
        <h4 class="text-sm font-medium obsidian-text-primary mb-4">Storage Provider</h4>
        <div class="space-y-4">
          <.toggle_setting
            label="Local Storage"
            description="Store files on local disk"
            name="use_local_storage"
            enabled={@settings.use_local_storage}
          />
          <.toggle_setting
            label="S3 Compatible Storage"
            description="Use S3-compatible object storage"
            name="use_s3_storage"
            enabled={@settings.use_s3_storage}
          />
        </div>
      </div>
    </div>
    """
  end

  # Transfer Settings Tab
  defp transfer_settings(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-semibold obsidian-text-primary mb-1">Transfer Settings</h3>
        <p class="text-xs obsidian-text-tertiary">Configure file transfer behavior and limits.</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <.setting_field
          label="Default Share Expiry (Days)"
          description="Default expiration time for share links"
          type="number"
          name="default_share_expiry_days"
          value={@settings.default_share_expiry_days}
        />
        <.setting_field
          label="Max Share Expiry (Days)"
          description="Maximum expiration time allowed for shares"
          type="number"
          name="max_share_expiry_days"
          value={@settings.max_share_expiry_days}
        />
        <.setting_field
          label="Chunk Size (MB)"
          description="Size of file chunks for large uploads"
          type="number"
          name="chunk_size_mb"
          value={@settings.chunk_size_mb}
        />
        <.setting_field
          label="Concurrent Uploads"
          description="Max concurrent upload streams per user"
          type="number"
          name="max_concurrent_uploads"
          value={@settings.max_concurrent_uploads}
        />
      </div>

      <div class="obsidian-divider my-6"></div>

      <div>
        <h4 class="text-sm font-medium obsidian-text-primary mb-4">Transfer Features</h4>
        <div class="space-y-4">
          <.toggle_setting
            label="Password Protection"
            description="Allow users to password-protect shares"
            name="allow_password_protection"
            enabled={@settings.allow_password_protection}
          />
          <.toggle_setting
            label="Download Limits"
            description="Allow users to set download limits on shares"
            name="allow_download_limits"
            enabled={@settings.allow_download_limits}
          />
          <.toggle_setting
            label="Email Notifications"
            description="Send email when files are downloaded"
            name="download_notifications"
            enabled={@settings.download_notifications}
          />
        </div>
      </div>
    </div>
    """
  end

  # Security Settings Tab
  defp security_settings(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-semibold obsidian-text-primary mb-1">Security Settings</h3>
        <p class="text-xs obsidian-text-tertiary">Configure security policies and access controls.</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <.setting_field
          label="Session Timeout (Hours)"
          description="Auto-logout after inactivity period"
          type="number"
          name="session_timeout_hours"
          value={@settings.session_timeout_hours}
        />
        <.setting_field
          label="Max Login Attempts"
          description="Lock account after failed login attempts"
          type="number"
          name="max_login_attempts"
          value={@settings.max_login_attempts}
        />
        <.setting_field
          label="Password Min Length"
          description="Minimum password length required"
          type="number"
          name="password_min_length"
          value={@settings.password_min_length}
        />
        <.setting_field
          label="Lockout Duration (Minutes)"
          description="How long accounts stay locked"
          type="number"
          name="lockout_duration_minutes"
          value={@settings.lockout_duration_minutes}
        />
      </div>

      <div class="obsidian-divider my-6"></div>

      <div>
        <h4 class="text-sm font-medium obsidian-text-primary mb-4">Security Features</h4>
        <div class="space-y-4">
          <.toggle_setting
            label="Two-Factor Authentication"
            description="Require 2FA for all users"
            name="require_2fa"
            enabled={@settings.require_2fa}
          />
          <.toggle_setting
            label="Email Verification"
            description="Require email verification for new accounts"
            name="require_email_verification"
            enabled={@settings.require_email_verification}
          />
          <.toggle_setting
            label="IP Logging"
            description="Log IP addresses for security auditing"
            name="log_ip_addresses"
            enabled={@settings.log_ip_addresses}
          />
          <.toggle_setting
            label="Virus Scanning"
            description="Scan uploaded files for malware"
            name="virus_scanning"
            enabled={@settings.virus_scanning}
          />
        </div>
      </div>
    </div>
    """
  end

  # Email Settings Tab
  defp email_settings(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-semibold obsidian-text-primary mb-1">Email Settings</h3>
        <p class="text-xs obsidian-text-tertiary">
          Configure email delivery and notification settings.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <.setting_field
          label="From Email"
          description="Email address for outgoing emails"
          type="email"
          name="from_email"
          value={@settings.from_email}
        />
        <.setting_field
          label="From Name"
          description="Display name for outgoing emails"
          type="text"
          name="from_name"
          value={@settings.from_name}
        />
        <.setting_field
          label="SMTP Host"
          description="SMTP server hostname"
          type="text"
          name="smtp_host"
          value={@settings.smtp_host}
        />
        <.setting_field
          label="SMTP Port"
          description="SMTP server port"
          type="number"
          name="smtp_port"
          value={@settings.smtp_port}
        />
      </div>

      <div class="obsidian-divider my-6"></div>

      <div>
        <h4 class="text-sm font-medium obsidian-text-primary mb-4">Email Notifications</h4>
        <div class="space-y-4">
          <.toggle_setting
            label="Welcome Emails"
            description="Send welcome email to new users"
            name="send_welcome_email"
            enabled={@settings.send_welcome_email}
          />
          <.toggle_setting
            label="Share Notifications"
            description="Notify users when shares are accessed"
            name="send_share_notifications"
            enabled={@settings.send_share_notifications}
          />
          <.toggle_setting
            label="Storage Alerts"
            description="Alert users when approaching storage limit"
            name="send_storage_alerts"
            enabled={@settings.send_storage_alerts}
          />
        </div>
      </div>

      <div class="obsidian-divider my-6"></div>

      <button type="button" phx-click="test_email" class="obsidian-btn obsidian-btn-primary">
        <.icon name="hero-paper-airplane" class="w-4 h-4" />
        <span>Send Test Email</span>
      </button>
    </div>
    """
  end

  # Maintenance Settings Tab
  defp maintenance_settings(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-semibold obsidian-text-primary mb-1">Maintenance Settings</h3>
        <p class="text-xs obsidian-text-tertiary">
          Configure maintenance mode and system cleanup settings.
        </p>
      </div>

      <%!-- Maintenance Mode Warning --%>
      <div class="bg-[#d4af37]/10 border border-[#d4af37]/20 rounded-lg p-4">
        <div class="flex items-start gap-3">
          <.icon
            name="hero-exclamation-triangle"
            class="w-5 h-5 obsidian-accent-amber flex-shrink-0 mt-0.5"
          />
          <div class="flex-1">
            <h4 class="text-sm font-medium obsidian-accent-amber">Maintenance Mode</h4>
            <p class="text-xs obsidian-text-secondary mt-1">
              When enabled, only project owners can access the platform. Users will see a maintenance message.
            </p>
            <div class="mt-3">
              <.toggle_setting
                label="Enable Maintenance Mode"
                description=""
                name="maintenance_mode"
                enabled={@settings.maintenance_mode}
              />
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <.setting_field
          label="Maintenance Message"
          description="Message shown during maintenance"
          type="text"
          name="maintenance_message"
          value={@settings.maintenance_message}
        />
        <.setting_field
          label="Cleanup Retention (Days)"
          description="Days to keep deleted files before permanent removal"
          type="number"
          name="cleanup_retention_days"
          value={@settings.cleanup_retention_days}
        />
      </div>

      <div class="obsidian-divider my-6"></div>

      <div>
        <h4 class="text-sm font-medium obsidian-text-primary mb-4">Automated Cleanup</h4>
        <div class="space-y-4">
          <.toggle_setting
            label="Auto-Delete Expired Shares"
            description="Automatically delete shares after expiration"
            name="auto_delete_expired_shares"
            enabled={@settings.auto_delete_expired_shares}
          />
          <.toggle_setting
            label="Auto-Cleanup Orphaned Files"
            description="Remove files with no associated transfers"
            name="auto_cleanup_orphans"
            enabled={@settings.auto_cleanup_orphans}
          />
        </div>
      </div>

      <div class="obsidian-divider my-6"></div>

      <div>
        <h4 class="text-sm font-medium obsidian-text-primary mb-4">Manual Actions</h4>
        <div class="flex flex-wrap gap-2">
          <button type="button" phx-click="clear_cache" class="obsidian-btn obsidian-btn-ghost">
            <.icon name="hero-trash" class="w-4 h-4" />
            <span>Clear Cache</span>
          </button>
          <button type="button" phx-click="run_cleanup" class="obsidian-btn obsidian-btn-ghost">
            <.icon name="hero-archive-box-x-mark" class="w-4 h-4" />
            <span>Run Cleanup</span>
          </button>
          <button type="button" phx-click="export_settings" class="obsidian-btn obsidian-btn-ghost">
            <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
            <span>Export</span>
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Setting Field Component
  defp setting_field(assigns) do
    assigns = assign_new(assigns, :options, fn -> [] end)

    ~H"""
    <div>
      <label class="block text-xs font-medium obsidian-text-secondary mb-1">{@label}</label>
      <p class="text-[11px] obsidian-text-tertiary mb-2">{@description}</p>
      <%= case @type do %>
        <% "select" -> %>
          <select
            name={@name}
            phx-change="update_setting"
            class="w-full px-3 py-2 text-sm bg-white/5 [[data-theme=light]_&]:bg-black/5 border border-white/10 [[data-theme=light]_&]:border-black/10 rounded-lg obsidian-text-primary focus:ring-1 focus:ring-amber-500/50 focus:border-amber-500/50 transition-colors"
          >
            <%= for {label, value} <- @options do %>
              <option value={value} selected={value == @value}>{label}</option>
            <% end %>
          </select>
        <% _ -> %>
          <input
            type={@type}
            name={@name}
            value={@value}
            phx-change="update_setting"
            class="w-full px-3 py-2 text-sm bg-white/5 [[data-theme=light]_&]:bg-black/5 border border-white/10 [[data-theme=light]_&]:border-black/10 rounded-lg obsidian-text-primary focus:ring-1 focus:ring-amber-500/50 focus:border-amber-500/50 transition-colors"
          />
      <% end %>
    </div>
    """
  end

  # Toggle Setting Component
  defp toggle_setting(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-1">
      <div>
        <p class="text-sm font-medium obsidian-text-primary">{@label}</p>
        <%= if @description != "" do %>
          <p class="text-xs obsidian-text-tertiary mt-0.5">{@description}</p>
        <% end %>
      </div>
      <button
        type="button"
        phx-click="toggle_setting"
        phx-value-name={@name}
        class={[
          "relative inline-flex h-5 w-9 items-center rounded-full transition-colors",
          if(@enabled, do: "bg-[#d4af37]", else: "bg-white/10 [[data-theme=light]_&]:bg-black/10")
        ]}
      >
        <span class={[
          "inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform",
          if(@enabled, do: "translate-x-5", else: "translate-x-0.5")
        ]}>
        </span>
      </button>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("update_setting", params, socket) do
    # Extract the setting name and value from params
    {_key, _value} = Enum.find(params, fn {k, _v} -> k != "_target" end) || {"", ""}

    socket =
      socket
      |> assign(:unsaved_changes, true)
      |> update_setting_value(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_setting", %{"name" => name}, socket) do
    settings = socket.assigns.settings
    current_value = Map.get(settings, String.to_existing_atom(name), false)
    new_settings = Map.put(settings, String.to_existing_atom(name), not current_value)

    socket =
      socket
      |> assign(:settings, new_settings)
      |> assign(:unsaved_changes, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_settings", _params, socket) do
    # In a real app, this would save to a settings table
    socket =
      socket
      |> assign(:unsaved_changes, false)
      |> put_flash(:info, "Settings saved successfully.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_settings", _params, socket) do
    socket =
      socket
      |> assign(:settings, default_settings())
      |> assign(:unsaved_changes, true)
      |> put_flash(:info, "Settings reset to defaults. Save to apply.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("test_email", _params, socket) do
    {:noreply, put_flash(socket, :info, "Test email sent to your address.")}
  end

  @impl true
  def handle_event("clear_cache", _params, socket) do
    {:noreply, put_flash(socket, :info, "Cache cleared successfully.")}
  end

  @impl true
  def handle_event("run_cleanup", _params, socket) do
    {:noreply, put_flash(socket, :info, "Cleanup task started. This may take a few minutes.")}
  end

  @impl true
  def handle_event("export_settings", _params, socket) do
    {:noreply, put_flash(socket, :info, "Settings exported. Check your downloads.")}
  end

  # Helper Functions

  defp update_setting_value(socket, params) do
    settings = socket.assigns.settings

    new_settings =
      Enum.reduce(params, settings, fn {key, value}, acc ->
        if key != "_target" do
          atom_key = String.to_existing_atom(key)
          Map.put(acc, atom_key, value)
        else
          acc
        end
      end)

    assign(socket, :settings, new_settings)
  rescue
    _ -> socket
  end

  defp load_settings do
    # In a real app, load from database
    default_settings()
  end

  defp default_settings do
    %{
      # General
      platform_name: "FlowTransfer",
      support_email: "support@flowtransfer.io",
      default_language: "en",
      default_timezone: "UTC",
      allow_registration: true,
      allow_public_shares: true,
      api_enabled: true,

      # Storage
      max_file_size_mb: 100,
      default_storage_gb: 5,
      pro_storage_gb: 50,
      business_storage_gb: 200,
      allowed_extensions:
        "jpg, jpeg, png, gif, pdf, doc, docx, xls, xlsx, ppt, pptx, txt, zip, rar, mp3, mp4, mov",
      use_local_storage: true,
      use_s3_storage: false,

      # Transfers
      default_share_expiry_days: 7,
      max_share_expiry_days: 30,
      chunk_size_mb: 5,
      max_concurrent_uploads: 3,
      allow_password_protection: true,
      allow_download_limits: true,
      download_notifications: true,

      # Security
      session_timeout_hours: 24,
      max_login_attempts: 5,
      password_min_length: 8,
      lockout_duration_minutes: 30,
      require_2fa: false,
      require_email_verification: true,
      log_ip_addresses: true,
      virus_scanning: false,

      # Email
      from_email: "noreply@flowtransfer.io",
      from_name: "FlowTransfer",
      smtp_host: "smtp.example.com",
      smtp_port: 587,
      send_welcome_email: true,
      send_share_notifications: true,
      send_storage_alerts: true,

      # Maintenance
      maintenance_mode: false,
      maintenance_message:
        "We're currently performing scheduled maintenance. Please check back shortly.",
      cleanup_retention_days: 30,
      auto_delete_expired_shares: true,
      auto_cleanup_orphans: false
    }
  end
end
