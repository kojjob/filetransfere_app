defmodule FiletransferWeb.Owner.UsersLiveEditTest do
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

    # Create a regular user to edit
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

  describe "user edit page" do
    test "renders edit form with pre-populated values", %{conn: conn, user: user} do
      # Navigate to edit page
      {:ok, view, html} = live(conn, ~p"/owner/users/#{user.id}/edit")

      # Verify page renders
      assert html =~ "Edit User"
      assert html =~ user.email

      # Verify form fields are pre-populated
      assert has_element?(view, "input[name='user[email]'][value='#{user.email}']")
      assert has_element?(view, "input[name='user[name]'][value='#{user.name}']")

      assert has_element?(
               view,
               "select[name='user[subscription_tier]'] option[value='free'][selected]"
             )
    end

    test "successfully updates user information", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users/#{user.id}/edit")

      # Update user information
      assert view
             |> form("form[phx-submit='save_user']", %{
               user: %{
                 email: "updated@test.com",
                 name: "Updated Name",
                 subscription_tier: "pro"
               }
             })
             |> render_submit()

      # Verify redirect to users list
      assert_redirect(view, ~p"/owner/users")

      # Verify user was updated in database
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.email == "updated@test.com"
      assert updated_user.name == "Updated Name"
      assert updated_user.subscription_tier == "pro"
    end

    test "shows validation errors for invalid email", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users/#{user.id}/edit")

      # Submit with invalid email
      view
      |> form("form[phx-submit='save_user']", %{
        user: %{
          email: "invalid-email",
          name: user.name
        }
      })
      |> render_submit()

      # Verify user was NOT updated in database (validation failed)
      unchanged_user = Accounts.get_user!(user.id)
      assert unchanged_user.email == user.email
    end

    test "prevents duplicate email addresses", %{conn: conn, user: user} do
      # Create another user
      {:ok, _other_user} =
        Accounts.create_user(%{
          email: "existing@test.com",
          password: "Password123!",
          name: "Existing User"
        })

      {:ok, view, _html} = live(conn, ~p"/owner/users/#{user.id}/edit")

      # Try to update to existing email
      view
      |> form("form[phx-submit='save_user']", %{
        user: %{
          email: "existing@test.com",
          name: user.name
        }
      })
      |> render_submit()

      # Verify user was NOT updated in database (unique constraint failed)
      unchanged_user = Accounts.get_user!(user.id)
      assert unchanged_user.email == user.email
    end

    test "allows canceling edit and returns to user list", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users/#{user.id}/edit")

      # Click cancel button
      view
      |> element("button", "Cancel")
      |> render_click()

      # Verify redirect to users list
      assert_redirect(view, ~p"/owner/users")

      # Verify user was not modified
      unchanged_user = Accounts.get_user!(user.id)
      assert unchanged_user.email == user.email
      assert unchanged_user.name == user.name
    end

    test "updates subscription tier and limits", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/owner/users/#{user.id}/edit")

      # Update subscription tier and limits
      assert view
             |> form("form[phx-submit='save_user']", %{
               user: %{
                 subscription_tier: "enterprise",
                 monthly_transfer_limit: 107_374_182_400,
                 max_file_size: 10_737_418_240,
                 api_calls_limit: 10_000
               }
             })
             |> render_submit()

      # Verify user was updated
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.subscription_tier == "enterprise"
      assert updated_user.monthly_transfer_limit == 107_374_182_400
      assert updated_user.max_file_size == 10_737_418_240
      assert updated_user.api_calls_limit == 10_000
    end

    test "non-owner cannot access edit page", %{user: user} do
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

      # Try to access edit page - should redirect to dashboard with error
      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               live(conn, ~p"/owner/users/#{user.id}/edit")
    end

    test "cannot edit non-existent user", %{conn: conn} do
      # Try to edit non-existent user (using a fake UUID that doesn't exist)
      fake_uuid = "00000000-0000-0000-0000-000000000000"

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/owner/users/#{fake_uuid}/edit")
      end
    end
  end
end
