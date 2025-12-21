defmodule FiletransferWeb.Owner.UsersLiveShowTest do
  use FiletransferWeb.ConnCase

  import Phoenix.LiveViewTest

  alias FiletransferCore.Accounts

  setup %{conn: conn} do
    # Create a project owner user for testing
    {:ok, owner} =
      Accounts.create_user(%{
        email: "owner@test.com",
        password: "Password123!",
        name: "Test Owner",
        subscription_tier: "enterprise"
      })

    {:ok, owner} = Accounts.update_user_role(owner, "project_owner")

    # Create a regular user to view
    {:ok, user} =
      Accounts.create_user(%{
        email: "user@test.com",
        password: "Password123!",
        name: "Test User",
        subscription_tier: "free"
      })

    # Manually set session (convert UUID to string for LiveAuth)
    user_id_string = to_string(owner.id)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user_id_string)

    %{conn: conn, owner: owner, user: user}
  end

  describe "user show page" do
    test "displays user details in modal", %{conn: conn, user: user} do
      # Navigate to show page
      {:ok, _view, html} = live(conn, ~p"/owner/users/#{user.id}")

      # Verify modal is displayed
      assert html =~ "User Details"
      assert html =~ "Viewing information for #{user.email}"

      # Verify basic information is displayed
      assert html =~ user.name
      assert html =~ user.email

      # Verify role badge is displayed
      assert html =~ "User"

      # Verify status badge is displayed
      assert html =~ "Active"
    end

    test "displays subscription details", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/owner/users/#{user.id}")

      # Verify subscription section
      assert html =~ "Subscription Details"
      assert html =~ "free"

      # Verify subscription limits are displayed
      assert html =~ "Monthly Transfer Limit"
      assert html =~ "Max File Size"
      assert html =~ "API Calls Limit"
    end

    test "displays account timestamps", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/owner/users/#{user.id}")

      # Verify account information section
      assert html =~ "Account Information"
      assert html =~ "Created"
      assert html =~ "Last Updated"
    end

    test "displays project owner badge for project owners", %{conn: conn, owner: owner} do
      {:ok, _view, html} = live(conn, ~p"/owner/users/#{owner.id}")

      # Verify project owner badge is displayed
      assert html =~ "Project Owner"
    end

    test "displays inactive status for inactive users", %{conn: conn, user: user} do
      # Deactivate the user
      {:ok, _inactive_user} = Accounts.deactivate_user(user)

      {:ok, _view, html} = live(conn, ~p"/owner/users/#{user.id}")

      # Verify inactive status badge is displayed
      assert html =~ "Inactive"
    end

    test "shows Edit User button linking to edit page", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users/#{user.id}")

      # Verify Edit User button is present and has correct link
      assert has_element?(view, "a[href='/owner/users/#{user.id}/edit']", "Edit User")
    end

    test "close button redirects to users list", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users/#{user.id}")

      # Click the close button
      view
      |> element("button", "Close")
      |> render_click()

      # Verify redirect to users list
      assert_redirect(view, ~p"/owner/users")
    end

    test "clicking backdrop closes modal and redirects to users list", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users/#{user.id}")

      # Click the backdrop (phx-click="close_details" on backdrop div)
      render_hook(view, "close_details", %{})

      # Verify redirect to users list
      assert_redirect(view, ~p"/owner/users")
    end

    test "non-owner cannot access show page", %{user: user} do
      # Create a regular user (not project owner)
      {:ok, regular_user} =
        Accounts.create_user(%{
          email: "regular@test.com",
          password: "Password123!",
          name: "Regular User"
        })

      # Create a new connection and log in as regular user
      conn = build_conn()
      user_id_string = to_string(regular_user.id)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user_id_string)

      # Try to access show page - should redirect to dashboard with error
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/owner/users/#{user.id}")
    end

    test "cannot view non-existent user", %{conn: conn} do
      # Try to view non-existent user (using a fake UUID that doesn't exist)
      fake_uuid = "00000000-0000-0000-0000-000000000000"

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/owner/users/#{fake_uuid}")
      end
    end

    test "displays enterprise subscription limits correctly", %{conn: conn, owner: owner} do
      # Update owner to have enterprise subscription with custom limits
      {:ok, updated_owner} =
        Accounts.update_user(owner, %{
          monthly_transfer_limit: 107_374_182_400,
          max_file_size: 10_737_418_240,
          api_calls_limit: 0
        })

      {:ok, _view, html} = live(conn, ~p"/owner/users/#{updated_owner.id}")

      # Verify enterprise limits are displayed
      assert html =~ "enterprise"
      # API calls limit should show Unlimited for 0
      assert html =~ "Unlimited"
    end

    test "displays formatted dates correctly", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/owner/users/#{user.id}")

      # Verify dates are formatted (they should contain month name and year)
      # We can't check exact format without knowing the timestamp, but we can check structure
      formatted_created = Calendar.strftime(user.inserted_at, "%B %d, %Y at %I:%M %p")
      formatted_updated = Calendar.strftime(user.updated_at, "%B %d, %Y at %I:%M %p")

      assert html =~ formatted_created
      assert html =~ formatted_updated
    end
  end
end
