defmodule FiletransferWeb.Dashboard.SettingsLiveTest do
  use FiletransferWeb.ConnCase

  import Phoenix.LiveViewTest

  alias FiletransferCore.Accounts

  setup %{conn: conn} do
    # Create a test user
    {:ok, user} =
      Accounts.create_user(%{
        email: "user@test.com",
        password: "Password123!",
        name: "Test User",
        subscription_tier: "free",
        monthly_transfer_limit: 10_737_418_240,
        max_file_size: 1_073_741_824,
        api_calls_limit: 1000,
        api_calls_used: 250
      })

    # Manually set session (convert UUID to string for LiveAuth)
    user_id_string = to_string(user.id)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user_id_string)

    %{conn: conn, user: user}
  end

  describe "settings page" do
    test "renders settings page with default profile tab", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      # Verify page title and description
      assert html =~ "Account Settings"
      assert html =~ "Manage your account preferences and security settings"

      # Verify tabs are present
      assert html =~ "Profile"
      assert html =~ "Security"
      assert html =~ "Notifications"
      assert html =~ "Billing"

      # Verify profile tab is active by default
      assert html =~ "Profile Information"
      assert html =~ user.name
      assert html =~ user.email
    end

    test "displays user information in profile tab", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings")

      # Verify user data is pre-filled
      assert html =~ user.name
      assert html =~ user.email
      assert html =~ "Save Changes"
    end

    test "tab switching works via URL params", %{conn: conn} do
      # Profile tab
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=profile")
      assert html =~ "Profile Information"
      assert html =~ "Update your personal details"

      # Security tab
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=security")
      assert html =~ "Change Password"
      assert html =~ "Current Password"
      assert html =~ "Two-Factor Authentication"
      assert html =~ "Active Sessions"

      # Notifications tab
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=notifications")
      assert html =~ "Notification Preferences"
      assert html =~ "Transfer Notifications"
      assert html =~ "Share Activity"
      assert html =~ "Security Alerts"
      assert html =~ "Product Updates"

      # Billing tab
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")
      assert html =~ "Current Plan"
      assert html =~ "Free"
      assert html =~ "Usage This Month"
      assert html =~ "Payment Methods"
    end

    test "non-authenticated user cannot access settings" do
      # Create a new connection without authentication
      conn = build_conn()

      # Try to access settings - should redirect to login
      assert {:error, {:redirect, redirect_info}} = live(conn, ~p"/dashboard/settings")
      assert redirect_info.to == "/login"
    end
  end

  describe "profile tab" do
    test "displays profile form with user data", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings?tab=profile")

      # Verify form fields exist
      assert has_element?(view, "input[name='user[name]'][value='#{user.name}']")
      assert has_element?(view, "input[name='user[email]'][value='#{user.email}']")
      assert has_element?(view, "button[type='submit']", "Save Changes")
    end

    test "updating profile information works", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings?tab=profile")

      # Submit profile update
      html =
        view
        |> form("form[phx-submit='save_profile']", %{
          user: %{name: "Updated Name", email: user.email}
        })
        |> render_submit()

      # Verify success message
      assert html =~ "Profile updated successfully"

      # Verify data was updated
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.name == "Updated Name"
    end

    test "profile form validates input", %{conn: conn, user: _user} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings?tab=profile")

      # Submit with invalid email
      html =
        view
        |> form("form[phx-submit='save_profile']", %{
          user: %{name: "Test", email: "invalid-email"}
        })
        |> render_submit()

      # Should not show success message
      refute html =~ "Profile updated successfully"
    end
  end

  describe "security tab" do
    test "displays password change form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings?tab=security")

      # Verify password form fields
      assert has_element?(view, "input[name='current_password'][type='password']")
      assert has_element?(view, "input[name='password'][type='password']")
      assert has_element?(view, "input[name='password_confirmation'][type='password']")
      assert has_element?(view, "button[type='submit']", "Update Password")
    end

    test "displays two-factor authentication section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=security")

      # Verify 2FA section
      assert html =~ "Two-Factor Authentication"
      assert html =~ "Authenticator App"
      assert html =~ "Not configured"
      assert html =~ "Set Up"
    end

    test "displays active sessions section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=security")

      # Verify sessions section
      assert html =~ "Active Sessions"
      assert html =~ "Current Session"
      assert html =~ "This device"
    end

    test "change password form submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings?tab=security")

      # Submit password change (currently shows coming soon message)
      html =
        view
        |> element("form[phx-submit='change_password']")
        |> render_submit()

      # Verify message is shown
      assert html =~ "Password change functionality coming soon"
    end
  end

  describe "notifications tab" do
    test "displays notification preferences", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=notifications")

      # Verify notification toggles
      assert html =~ "Transfer Notifications"
      assert html =~ "Share Activity"
      assert html =~ "Security Alerts"
      assert html =~ "Product Updates"

      # Verify descriptions
      assert html =~ "Get notified when your transfers complete or fail"
      assert html =~ "Get notified when someone accesses your shared files"
      assert html =~ "Get notified about security events like new sign-ins"
      assert html =~ "Receive news about new features and improvements"
    end

    test "notification toggles have correct initial states", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings?tab=notifications")

      # Email transfers, shares, and security should be checked
      assert has_element?(view, "input[name='email_transfers'][checked]")
      assert has_element?(view, "input[name='email_shares'][checked]")
      assert has_element?(view, "input[name='email_security'][checked]")

      # Marketing should not be checked
      refute has_element?(view, "input[name='email_marketing'][checked]")
    end

    test "saving notification preferences", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings?tab=notifications")

      # Submit notification preferences
      html =
        view
        |> element("form[phx-submit='save_notifications']")
        |> render_submit()

      # Verify success message
      assert html =~ "Notification preferences saved"
    end
  end

  describe "billing tab" do
    test "displays current plan information", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")

      # Verify plan display
      assert html =~ "Current Plan"
      assert html =~ String.capitalize(user.subscription_tier)
      assert html =~ "Upgrade Plan"
    end

    test "displays plan limits", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")

      # Verify limit displays
      assert html =~ "Monthly Transfer"
      assert html =~ "10.0 GB"
      assert html =~ "Max File Size"
      assert html =~ "1.0 GB"
      assert html =~ "API Calls"
      assert html =~ "1000/month"
    end

    test "displays usage statistics", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")

      # Verify usage bars
      assert html =~ "Usage This Month"
      assert html =~ "Transfer Usage"
      assert html =~ "API Calls"

      # Verify API usage is displayed
      assert html =~ "#{user.api_calls_used}"
      assert html =~ "#{user.api_calls_limit}"
    end

    test "displays payment methods section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")

      # Verify payment section
      assert html =~ "Payment Methods"

      # For free user without payment method
      assert html =~ "Add Payment Method"
    end

    test "displays existing payment method when user has stripe_customer_id", %{
      conn: conn,
      user: user
    } do
      # Update user with stripe_customer_id
      {:ok, _updated_user} = Accounts.update_user(user, %{stripe_customer_id: "cus_test123"})

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")

      # Verify payment method is displayed
      assert html =~ "•••• •••• •••• 4242"
      assert html =~ "Expires 12/25"
      assert html =~ "Update"
    end

    test "usage bar calculation works correctly", %{conn: conn, user: user} do
      # Update API usage to 80% (800 out of 1000)
      {:ok, _updated_user} = Accounts.update_user(user, %{api_calls_used: 800})

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")

      # Verify usage display
      assert html =~ "800"
      assert html =~ "1000"

      # API usage is at 80%, so it should show red color
      assert html =~ "bg-red-500"
    end

    test "usage bar shows blue when under 80%", %{conn: conn, user: user} do
      # Keep API usage at 25% (250 out of 1000)
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")

      # Verify usage display
      assert html =~ "#{user.api_calls_used}"
      assert html =~ "#{user.api_calls_limit}"

      # API usage is at 25%, so it should show blue color
      assert html =~ "bg-blue-500"
    end
  end

  describe "helper functions" do
    test "format_bytes formats different byte sizes correctly" do
      # Test via the billing tab display
      {:ok, user} =
        Accounts.create_user(%{
          email: "format@test.com",
          password: "Password123!",
          name: "Format Test",
          subscription_tier: "pro",
          monthly_transfer_limit: 1_073_741_824,
          max_file_size: 5_368_709_120,
          api_calls_limit: 10000
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, to_string(user.id))

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")

      # Verify byte formatting
      assert html =~ "1.0 GB"
      assert html =~ "5.0 GB"
    end

    test "format_api_calls formats different values correctly" do
      # Test via the billing tab display
      {:ok, user} =
        Accounts.create_user(%{
          email: "api@test.com",
          password: "Password123!",
          name: "API Test",
          subscription_tier: "free",
          monthly_transfer_limit: 1_073_741_824,
          max_file_size: 1_073_741_824,
          api_calls_limit: 0
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, to_string(user.id))

      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=billing")

      # Verify 0 API calls shows "None"
      assert html =~ "None"
    end
  end

  describe "tab navigation" do
    test "clicking tab links navigates to correct tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      # Click security tab
      view
      |> element("a[href='/dashboard/settings?tab=security']")
      |> render_click()

      # Verify URL changed and content updated
      assert_patch(view, "/dashboard/settings?tab=security")

      # Click notifications tab
      view
      |> element("a[href='/dashboard/settings?tab=notifications']")
      |> render_click()

      assert_patch(view, "/dashboard/settings?tab=notifications")

      # Click billing tab
      view
      |> element("a[href='/dashboard/settings?tab=billing']")
      |> render_click()

      assert_patch(view, "/dashboard/settings?tab=billing")

      # Click profile tab
      view
      |> element("a[href='/dashboard/settings?tab=profile']")
      |> render_click()

      assert_patch(view, "/dashboard/settings?tab=profile")
    end

    test "active tab has correct styling", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/settings?tab=security")

      # Security tab should have active class (blue color and border)
      assert html =~ "text-blue-600"
      assert html =~ "border-blue-600"
    end
  end
end
