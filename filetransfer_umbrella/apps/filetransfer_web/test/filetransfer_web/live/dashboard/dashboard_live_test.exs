defmodule FiletransferWeb.Dashboard.DashboardLiveTest do
  use FiletransferWeb.ConnCase

  import Phoenix.LiveViewTest

  alias FiletransferCore.Accounts
  alias FiletransferCore.Transfers
  alias FiletransferCore.Sharing

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

  describe "dashboard page" do
    test "renders dashboard with welcome message", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify welcome message
      assert html =~ "Welcome back, #{user.name}!"
      assert html =~ "Here&#39;s an overview of your file transfer activity"
    end

    test "displays user statistics", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify stats cards are present
      assert html =~ "Total Transfers"
      assert html =~ "Active Shares"
      assert html =~ "Storage Used"
    end

    test "shows empty state for recent transfers when no transfers exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify empty state for transfers
      assert html =~ "Recent Transfers"
      assert html =~ "No transfers yet"
      assert html =~ "Your recent file transfers will appear here"
    end

    test "shows empty state for recent shares when no shares exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify empty state for shares
      assert html =~ "Recent Shares"
      assert html =~ "No active shares"
      assert html =~ "Your share links will appear here"
    end

    test "displays recent transfers when they exist", %{conn: conn, user: user} do
      # Create a test transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test-file.pdf",
          file_size: 1_048_576,
          total_chunks: 1
        })

      # Update status to completed
      {:ok, _transfer} = Transfers.update_transfer(transfer, %{status: "completed"})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify transfer is displayed
      assert html =~ "test-file.pdf"
      assert html =~ "1.0 MB"
      assert html =~ "completed"
    end

    test "displays recent shares when they exist", %{conn: conn, user: user} do
      # Create a test transfer first
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "shared-file.pdf",
          file_size: 2_097_152,
          total_chunks: 1,
          status: "completed"
        })

      # Create a share link
      {:ok, _share} = Sharing.create_share_link(transfer, user)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify share is displayed (checking for transfer filename instead)
      assert html =~ "shared-file.pdf"
      assert html =~ "0 downloads"
    end

    test "displays quick action buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify quick action buttons
      assert html =~ "Quick Actions"
      assert html =~ "New Transfer"
      assert html =~ "Create Share Link"
      assert html =~ "View Files"
      assert html =~ "Settings"
    end

    test "quick action buttons have correct navigation links", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Verify navigation links exist
      assert has_element?(view, "a[href='/dashboard/transfers/new']")
      assert has_element?(view, "a[href='/dashboard/shares/new']")
      assert has_element?(view, "a[href='/dashboard/transfers']")
      assert has_element?(view, "a[href='/dashboard/settings']")
    end

    test "view all transfers link navigates to transfers page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Verify "View all" link for transfers exists
      assert has_element?(view, "a[href='/dashboard/transfers']", "View all")
    end

    test "view all shares link navigates to shares page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Verify "View all" link for shares exists
      assert has_element?(view, "a[href='/dashboard/shares']", "View all")
    end

    test "copy share link button shows flash message", %{conn: conn, user: user} do
      # Create a test transfer and share
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "file.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, share} = Sharing.create_share_link(transfer, user)

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Click copy share link button
      html =
        view
        |> element("button[phx-click='copy_share_link'][phx-value-id='#{share.id}']")
        |> render_click()

      # Verify flash message
      assert html =~ "Share link copied to clipboard!"
    end

    test "displays transfer status with correct styling", %{conn: conn, user: user} do
      # Create transfers with different statuses
      {:ok, _completed} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "completed.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, _pending} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "pending.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "pending"
        })

      {:ok, _failed} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "failed.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "failed"
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify all transfers are displayed with their statuses
      assert html =~ "completed.pdf"
      assert html =~ "pending.pdf"
      assert html =~ "failed.pdf"
      assert html =~ "completed"
      assert html =~ "pending"
      assert html =~ "failed"
    end

    test "formats file sizes correctly", %{conn: conn, user: user} do
      # Create transfers with different file sizes
      {:ok, _bytes} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "small.txt",
          file_size: 512,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, _kb} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "medium.txt",
          file_size: 1024 * 50,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, _mb} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "large.txt",
          file_size: 1_048_576 * 5,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify file sizes are formatted
      assert html =~ "512 B"
      assert html =~ "50.0 KB"
      assert html =~ "5.0 MB"
    end

    test "displays correct share download count pluralization", %{conn: conn, user: user} do
      # Create transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "file.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      # Create share with 0 downloads initially
      {:ok, share} = Sharing.create_share_link(transfer, user)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify plural form for 0 downloads
      assert html =~ "0 downloads"

      # Update to 1 download
      {:ok, _updated} = Sharing.update_share_link(share, %{download_count: 1})

      {:ok, _view2, html2} = live(conn, ~p"/dashboard")

      # Verify singular form
      assert html2 =~ "1 download"
      refute html2 =~ "1 downloads"

      # Update to multiple downloads
      {:ok, _updated2} = Sharing.update_share_link(share, %{download_count: 5})

      {:ok, _view3, html3} = live(conn, ~p"/dashboard")

      # Verify plural form
      assert html3 =~ "5 downloads"
    end

    test "non-authenticated user cannot access dashboard" do
      # Create a new connection without authentication
      conn = build_conn()

      # Try to access dashboard - should redirect to login
      assert {:error, {:redirect, redirect_info}} = live(conn, ~p"/dashboard")
      assert redirect_info.to == "/login"
    end

    test "displays formatted dates correctly", %{conn: conn, user: user} do
      # Create a transfer with known timestamp
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1,
          status: "completed"
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify date is formatted (format: "Mon DD, YYYY")
      formatted_date = Calendar.strftime(transfer.inserted_at, "%b %d, %Y")
      assert html =~ formatted_date
    end
  end
end
