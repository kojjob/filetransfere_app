defmodule FiletransferWeb.Dashboard.SharesLiveTest do
  use FiletransferWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias FiletransferCore.Accounts
  alias FiletransferCore.Transfers
  alias FiletransferCore.Sharing
  alias FiletransferCore.Repo

  setup %{conn: conn} do
    # Create a test user
    {:ok, user} =
      Accounts.create_user(%{
        email: "user@test.com",
        password: "Password123!",
        name: "Test User",
        subscription_tier: "free"
      })

    # Manually set session (convert UUID to string for LiveAuth)
    user_id_string = to_string(user.id)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user_id_string)

    %{conn: conn, user: user}
  end

  describe "shares page" do
    test "renders shares page with header and create button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/shares")

      # Verify header content
      assert html =~ "Share Links"
      assert html =~ "Manage your file sharing links and permissions"

      # Verify create button exists
      assert html =~ "Create Share Link"
      assert html =~ "/dashboard/shares/new"
    end

    test "displays filter tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/shares")

      # Verify all filter tabs exist
      assert has_element?(view, "a", "Active")
      assert has_element?(view, "a", "Expired")
      assert has_element?(view, "a", "All")
    end

    test "shows empty state when no shares exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/shares")

      # Verify empty state message
      assert html =~ "No share links found"
      assert html =~ "You don&#39;t have any active share links"
    end

    test "displays active shares", %{conn: conn, user: user} do
      # Create a test transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test-file.pdf",
          file_size: 1_048_576,
          total_chunks: 1,
          status: "completed"
        })

      # Create an active share (expires in 24 hours)
      {:ok, _share} = Sharing.create_share_link(transfer, user, expires_in: 24 * 3600)

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares")

      # Verify share is displayed
      assert html =~ "Share Link"
      assert html =~ "Active"
      assert html =~ "0 downloads"
    end

    test "displays expired shares when filtered", %{conn: conn, user: user} do
      # Create a test transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "expired-file.pdf",
          file_size: 2_097_152,
          total_chunks: 1,
          status: "completed"
        })

      # Create an expired share (create with short expiry, then update to past)
      {:ok, share} = Sharing.create_share_link(transfer, user, expires_in: 1)
      expires_at = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)
      # Use Repo.update_all to bypass changeset validation for test data
      Repo.update_all(
        from(s in FiletransferCore.Sharing.ShareLink, where: s.id == ^share.id),
        set: [expires_at: expires_at]
      )

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares?filter=expired")

      # Verify expired share is displayed
      assert html =~ "Expired"
    end

    test "shows password protection indicator", %{conn: conn, user: user} do
      # Create a test transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "protected-file.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create a password-protected share
      {:ok, _share} = Sharing.create_share_link(transfer, user, password: "SecurePass123")

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares")

      # Verify password indicator is shown
      assert html =~ "Password protected"
    end

    test "shows max downloads limit", %{conn: conn, user: user} do
      # Create a test transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "limited-file.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create a share with download limit
      {:ok, _share} = Sharing.create_share_link(transfer, user, max_downloads: 5)

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares")

      # Verify download limit is shown
      assert html =~ "0/5 downloads"
    end

    test "displays share URL", %{conn: conn, user: user} do
      # Create a test transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "share-url-test.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create a share
      {:ok, share} = Sharing.create_share_link(transfer, user)

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares")

      # Verify share URL is displayed (at least the token part)
      assert html =~ "/s/#{share.token || share.id}"
    end

    test "copy link button shows flash message", %{conn: conn, user: user} do
      # Create a test transfer and share
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "copy-test.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, share} = Sharing.create_share_link(transfer, user)

      {:ok, view, _html} = live(conn, ~p"/dashboard/shares")

      # Click copy link button
      html =
        view
        |> element("button[phx-click='copy_link'][phx-value-id='#{share.id}']")
        |> render_click()

      # Verify flash message
      assert html =~ "Share link copied to clipboard!"
    end

    test "edit button navigates to edit page", %{conn: conn, user: user} do
      # Create a test transfer and share
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "edit-test.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, share} = Sharing.create_share_link(transfer, user)

      {:ok, view, _html} = live(conn, ~p"/dashboard/shares")

      # Click edit button (triggers redirect)
      view
      |> element("button[phx-click='edit'][phx-value-id='#{share.id}']")
      |> render_click()

      # Verify redirect happened
      assert_redirect(view, "/dashboard/shares/#{share.id}/edit")
    end

    test "view stats button navigates to stats page", %{conn: conn, user: user} do
      # Create a test transfer and share
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "stats-test.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, share} = Sharing.create_share_link(transfer, user)

      {:ok, view, _html} = live(conn, ~p"/dashboard/shares")

      # Click view stats button (triggers redirect)
      view
      |> element("button[phx-click='view_stats'][phx-value-id='#{share.id}']")
      |> render_click()

      # Verify redirect happened
      assert_redirect(view, "/dashboard/shares/#{share.id}/stats")
    end

    test "revoke button revokes active share", %{conn: conn, user: user} do
      # Create a test transfer and active share
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "revoke-test.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, share} = Sharing.create_share_link(transfer, user)

      {:ok, view, _html} = live(conn, ~p"/dashboard/shares")

      # Click revoke button
      html =
        view
        |> element("button[phx-click='revoke'][phx-value-id='#{share.id}']")
        |> render_click()

      # Verify flash message
      assert html =~ "Share link has been revoked"
    end

    test "delete button removes share", %{conn: conn, user: user} do
      # Create a test transfer and share
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "delete-test.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, share} = Sharing.create_share_link(transfer, user)

      {:ok, view, _html} = live(conn, ~p"/dashboard/shares")

      # Click delete button
      html =
        view
        |> element("button[phx-click='delete'][phx-value-id='#{share.id}']")
        |> render_click()

      # Verify flash message
      assert html =~ "Share link deleted successfully"
    end

    test "non-authenticated user cannot access shares page" do
      # Create a new connection without authentication
      conn = build_conn()

      # Try to access shares - should redirect to login
      assert {:error, {:redirect, redirect_info}} = live(conn, ~p"/dashboard/shares")
      assert redirect_info.to == "/login"
    end

    test "displays download count correctly", %{conn: conn, user: user} do
      # Create a test transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "download-count-test.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create a share with downloads
      {:ok, share} = Sharing.create_share_link(transfer, user)
      {:ok, _updated} = Sharing.update_share_link(share, %{download_count: 3})

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares")

      # Verify download count is displayed
      assert html =~ "3 downloads"
    end

    test "pluralizes download count correctly", %{conn: conn, user: user} do
      # Create transfers for singular and plural tests
      {:ok, transfer1} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "singular.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, transfer2} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "plural.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create shares with different download counts
      {:ok, share1} = Sharing.create_share_link(transfer1, user)
      {:ok, _updated1} = Sharing.update_share_link(share1, %{download_count: 1})

      {:ok, share2} = Sharing.create_share_link(transfer2, user)
      {:ok, _updated2} = Sharing.update_share_link(share2, %{download_count: 5})

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares")

      # Verify singular
      assert html =~ "1 download"
      refute html =~ "1 downloads"

      # Verify plural
      assert html =~ "5 downloads"
    end
  end

  describe "filtering" do
    test "filter by active shows only active shares", %{conn: conn, user: user} do
      # Create transfers
      {:ok, active_transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "active-share.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, expired_transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "expired-share.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create active share (expires in future)
      {:ok, _active_share} = Sharing.create_share_link(active_transfer, user, expires_in: 24 * 3600)

      # Create expired share (create with short expiry, then update to past)
      {:ok, expired_share} = Sharing.create_share_link(expired_transfer, user, expires_in: 1)
      expires_past = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)
      # Use Repo.update_all to bypass changeset validation for test data
      Repo.update_all(
        from(s in FiletransferCore.Sharing.ShareLink, where: s.id == ^expired_share.id),
        set: [expires_at: expires_past]
      )

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares?filter=active")

      # Should show only active share
      assert html =~ "active-share.pdf"
      refute html =~ "expired-share.pdf"
    end

    test "filter by expired shows only expired shares", %{conn: conn, user: user} do
      # Create transfers
      {:ok, active_transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "active-share.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, expired_transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "expired-share.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create active share (expires far in future)
      {:ok, _active_share} = Sharing.create_share_link(active_transfer, user, expires_in: 365 * 24 * 3600)

      # Create expired share (create with short expiry, then update to past)
      {:ok, expired_share} = Sharing.create_share_link(expired_transfer, user, expires_in: 1)
      expires_past = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)
      {1, _} = Repo.update_all(
        from(s in FiletransferCore.Sharing.ShareLink, where: s.id == ^expired_share.id),
        set: [expires_at: expires_past]
      )

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares?filter=expired")

      # Should show only expired share
      refute html =~ "active-share.pdf"
      assert html =~ "expired-share.pdf"
    end

    test "filter by all shows all shares", %{conn: conn, user: user} do
      # Create transfers
      {:ok, active_transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "active-share.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, expired_transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "expired-share.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create active share
      {:ok, _active_share} = Sharing.create_share_link(active_transfer, user, expires_in: 24 * 3600)

      # Create expired share
      {:ok, expired_share} = Sharing.create_share_link(expired_transfer, user, expires_in: 1)
      expires_past = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)
      # Use Repo.update_all to bypass changeset validation
      Repo.update_all(
        from(s in FiletransferCore.Sharing.ShareLink, where: s.id == ^expired_share.id),
        set: [expires_at: expires_past]
      )

      {:ok, _view, html} = live(conn, ~p"/dashboard/shares?filter=all")

      # Should show both shares
      assert html =~ "active-share.pdf"
      assert html =~ "expired-share.pdf"
    end

    test "clicking filter tabs updates the list", %{conn: conn, user: user} do
      # Create test shares
      {:ok, active_transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "active.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, expired_transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "expired.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create shares
      {:ok, _active} = Sharing.create_share_link(active_transfer, user, expires_in: 24 * 3600)

      {:ok, expired} = Sharing.create_share_link(expired_transfer, user, expires_in: 1)
      expires_past = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)
      # Use Repo.update_all to bypass changeset validation
      Repo.update_all(
        from(s in FiletransferCore.Sharing.ShareLink, where: s.id == ^expired.id),
        set: [expires_at: expires_past]
      )

      {:ok, view, _html} = live(conn, ~p"/dashboard/shares")

      # Click "Expired" filter
      view
      |> element("a[href='/dashboard/shares?filter=expired']")
      |> render_click()

      # Verify only expired shown
      html = render(view)
      refute html =~ "active.pdf"
      assert html =~ "expired.pdf"

      # Click "All" filter
      view
      |> element("a[href='/dashboard/shares?filter=all']")
      |> render_click()

      # Verify both shown
      html = render(view)
      assert html =~ "active.pdf"
      assert html =~ "expired.pdf"
    end
  end

  describe "empty states" do
    test "shows active empty state message", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/shares?filter=active")

      assert html =~ "No share links found"
      assert html =~ "You don&#39;t have any active share links"
    end

    test "shows expired empty state message", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/shares?filter=expired")

      assert html =~ "No share links found"
      assert html =~ "You don&#39;t have any expired share links"
    end

    test "shows all empty state message", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/shares?filter=all")

      assert html =~ "No share links found"
      assert html =~ "Create your first share link to share files"
    end
  end
end
