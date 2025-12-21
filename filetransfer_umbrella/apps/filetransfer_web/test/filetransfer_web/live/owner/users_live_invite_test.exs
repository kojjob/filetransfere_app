defmodule FiletransferWeb.Owner.UsersLiveInviteTest do
  use FiletransferWeb.ConnCase

  import Phoenix.LiveViewTest

  alias FiletransferCore.Accounts

  describe "User Invite Flow /owner/users/new" do
    setup %{conn: conn} do
      # Create user first
      {:ok, owner} =
        Accounts.create_user(%{
          email: "testowner@example.com",
          password: "Password123!",
          name: "Test Owner",
          subscription_tier: "enterprise"
        })

      # Then update role to project_owner (registration_changeset doesn't include role)
      {:ok, owner} = Accounts.update_user_role(owner, "project_owner")

      # Manually set session (convert UUID to string for LiveAuth)
      user_id_string = to_string(owner.id)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user_id_string)

      %{conn: conn, owner: owner}
    end

    test "renders invite modal", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/owner/users/new")

      assert html =~ "Invite User"
      assert html =~ "Name"
      assert html =~ "Email"
      assert html =~ "Temporary Password"
      assert html =~ "Role"
      assert html =~ "Subscription Tier"
    end

    test "creates user on valid submission", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/owner/users/new")

      assert index_live
             |> form("#invite-user-form",
               user: %{
                 name: "New User",
                 email: "newuser@test.com",
                 password: "Password123!",
                 role: "user",
                 subscription_tier: "free"
               }
             )
             |> render_submit()

      assert_redirected(index_live, ~p"/owner/users")

      # Verify user was created
      assert FiletransferCore.Accounts.get_user_by_email("newuser@test.com")
    end

    test "shows validation errors on invalid submission", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/owner/users/new")

      html =
        index_live
        |> form("#invite-user-form",
          user: %{
            name: "New User",
            # Invalid: empty email
            email: "",
            # Invalid: too short password
            password: "short"
          }
        )
        |> render_submit()

      assert html =~ "Failed to create user"
    end

    test "cancel button navigates back to users list", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/owner/users/new")

      index_live
      |> element("button", "Cancel")
      |> render_click()

      assert_redirected(index_live, ~p"/owner/users")
    end
  end
end
