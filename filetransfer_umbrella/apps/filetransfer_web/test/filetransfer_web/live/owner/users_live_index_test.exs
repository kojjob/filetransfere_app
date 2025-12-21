defmodule FiletransferWeb.Owner.UsersLiveIndexTest do
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

    # Create test users with different statuses and roles
    {:ok, active_user} =
      Accounts.create_user(%{
        email: "active@test.com",
        password: "Password123!",
        name: "Active User",
        subscription_tier: "free"
      })

    {:ok, inactive_user} =
      Accounts.create_user(%{
        email: "inactive@test.com",
        password: "Password123!",
        name: "Inactive User",
        subscription_tier: "pro"
      })

    {:ok, inactive_user} = Accounts.deactivate_user(inactive_user)

    {:ok, another_owner} =
      Accounts.create_user(%{
        email: "owner2@test.com",
        password: "Password123!",
        name: "Another Owner",
        subscription_tier: "enterprise"
      })

    {:ok, another_owner} = Accounts.update_user_role(another_owner, "project_owner")

    # Manually set session (convert UUID to string for LiveAuth)
    user_id_string = to_string(owner.id)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user_id_string)

    %{
      conn: conn,
      owner: owner,
      active_user: active_user,
      inactive_user: inactive_user,
      another_owner: another_owner
    }
  end

  describe "users index page" do
    test "renders users list with all users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/owner/users")

      # Verify page renders
      assert html =~ "Users"
      assert html =~ "All"
      assert html =~ "Active"
      assert html =~ "Inactive"
      assert html =~ "Owners"

      # Verify users are displayed
      assert html =~ "Test Owner"
      assert html =~ "Active User"
      assert html =~ "Inactive User"
      assert html =~ "Another Owner"
    end

    test "displays user information in table", %{conn: conn, active_user: user} do
      {:ok, _view, html} = live(conn, ~p"/owner/users")

      # Verify user details are shown
      assert html =~ user.name
      assert html =~ user.email

      # Verify role badge
      assert html =~ "User"

      # Verify subscription tier (capitalized in UI)
      assert html =~ "Free"

      # Verify status
      assert html =~ "Active"
    end

    test "shows project owner badge for owners", %{conn: conn, another_owner: owner} do
      {:ok, _view, html} = live(conn, ~p"/owner/users")

      # Find the owner's row and verify role badge
      assert html =~ owner.name
      assert html =~ "Project Owner"
    end

    test "filter by active users", %{conn: conn, active_user: active, inactive_user: inactive} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Navigate to filtered URL
      html = view |> element("a[href*='filter=active']") |> render_click()

      # Active user should be shown
      assert html =~ active.name

      # Inactive user should not be shown
      refute html =~ inactive.name
    end

    test "filter by inactive users", %{conn: conn, active_user: active, inactive_user: inactive} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Navigate to filtered URL
      html = view |> element("a[href*='filter=inactive']") |> render_click()

      # Inactive user should be shown
      assert html =~ inactive.name

      # Active user should not be shown
      refute html =~ active.name
    end

    test "filter by project owners", %{
      conn: conn,
      owner: owner,
      another_owner: another_owner,
      active_user: regular_user
    } do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Navigate to filtered URL
      html = view |> element("a[href*='filter=project_owner']") |> render_click()

      # Owners should be shown
      assert html =~ owner.name
      assert html =~ another_owner.name

      # Regular user should not be shown
      refute html =~ regular_user.name
    end

    test "search users by name", %{conn: conn, active_user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Search by user name
      html =
        view
        |> form("form[phx-submit='search']", %{search: "Active"})
        |> render_submit()

      # Matching user should be shown
      assert html =~ user.name

      # Non-matching users should not be shown
      refute html =~ "Another Owner"
    end

    test "search users by email", %{conn: conn, active_user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Search by email
      html =
        view
        |> form("form[phx-submit='search']", %{search: "active@"})
        |> render_submit()

      # Matching user should be shown
      assert html =~ user.email

      # Non-matching users should not be shown
      refute html =~ "owner2@test.com"
    end

    test "clear search returns all users", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Search for specific user
      view
      |> form("form[phx-submit='search']", %{search: "Active"})
      |> render_submit()

      # Clear search
      html =
        view
        |> form("form[phx-submit='search']", %{search: ""})
        |> render_submit()

      # All users should be shown again
      assert html =~ "Test Owner"
      assert html =~ "Active User"
      assert html =~ "Another Owner"
    end

    test "view user button navigates to show page", %{conn: conn, active_user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Click view button
      view
      |> element("button[phx-click='view_user'][phx-value-id='#{user.id}']")
      |> render_click()

      # Should navigate to show page
      assert_redirect(view, ~p"/owner/users/#{user.id}")
    end

    test "edit user button navigates to edit page", %{conn: conn, active_user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Click edit button
      view
      |> element("button[phx-click='edit_user'][phx-value-id='#{user.id}']")
      |> render_click()

      # Should navigate to edit page
      assert_redirect(view, ~p"/owner/users/#{user.id}/edit")
    end

    test "promote user to project owner", %{conn: conn, active_user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Promote user
      html =
        view
        |> element("button[phx-click='promote_user'][phx-value-id='#{user.id}']")
        |> render_click()

      # Verify user was promoted
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.role == "project_owner"

      # Page should show success message
      assert html =~ "User promoted to Project Owner successfully"
    end

    test "demote project owner to regular user", %{conn: conn, another_owner: owner} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Demote owner
      html =
        view
        |> element("button[phx-click='demote_user'][phx-value-id='#{owner.id}']")
        |> render_click()

      # Verify user was demoted
      updated_user = Accounts.get_user!(owner.id)
      assert updated_user.role == "user"

      # Page should show success message
      assert html =~ "User demoted to regular user successfully"
    end

    test "toggle user status from active to inactive", %{conn: conn, active_user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Deactivate user
      html =
        view
        |> element("button[phx-click='toggle_status'][phx-value-id='#{user.id}']")
        |> render_click()

      # Verify user was deactivated
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.is_active == false

      # Page should show success message (with period)
      assert html =~ "User deactivated successfully."
    end

    test "toggle user status from inactive to active", %{conn: conn, inactive_user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Activate user
      html =
        view
        |> element("button[phx-click='toggle_status'][phx-value-id='#{user.id}']")
        |> render_click()

      # Verify user was activated
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.is_active == true

      # Page should show success message (with period)
      assert html =~ "User activated successfully."
    end

    test "export users button shows flash message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Click export button
      html =
        view
        |> element("button[phx-click='export_users']")
        |> render_click()

      # Should show export message
      assert html =~ "Exporting users... Download will start shortly"
    end

    test "invite user link navigates to new user page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Verify Invite User link is present
      assert has_element?(view, "a[href='/owner/users/new']")
    end

    test "non-owner cannot access users index" do
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

      # Try to access users index - should redirect to dashboard with error
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/owner/users")
    end

    test "displays empty state when no users match filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Search for non-existent user
      html =
        view
        |> form("form[phx-submit='search']", %{search: "NonexistentUserXYZ"})
        |> render_submit()

      # Should show empty state message
      assert html =~ "No users found"
    end

    test "combined search and filter", %{conn: conn, active_user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users")

      # Filter by active users
      view
      |> element("a[href*='filter=active']")
      |> render_click()

      # Then search within active users
      html =
        view
        |> form("form[phx-submit='search']", %{search: "Active"})
        |> render_submit()

      # Should show active user matching search
      assert html =~ user.name

      # Should not show inactive users even if they match search
      refute html =~ "Inactive User"
    end
  end
end
