defmodule FiletransferWeb.Dashboard.TransfersLiveTest do
  use FiletransferWeb.ConnCase

  import Phoenix.LiveViewTest

  alias FiletransferCore.Accounts
  alias FiletransferCore.Transfers

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

  describe "transfers page" do
    test "renders transfers page with header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify page title and description
      assert html =~ "My Transfers"
      assert html =~ "Manage your file transfers and uploads"
    end

    test "displays New Transfer button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Verify New Transfer button is present and has correct link
      assert has_element?(view, "a[href='/dashboard/transfers/new']", "New Transfer")
    end

    test "displays filter buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify all filter buttons are present
      assert html =~ "All"
      assert html =~ "Completed"
      assert html =~ "Pending"
      assert html =~ "Failed"
    end

    test "displays search form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Verify search input is present
      assert has_element?(view, "input[name='search'][placeholder='Search transfers...']")
    end

    test "shows empty state when no transfers exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify empty state message
      assert html =~ "No transfers found"
      assert html =~ "Upload your first file to get started"
    end

    test "displays transfers when they exist", %{conn: conn, user: user} do
      # Create a test transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test-file.pdf",
          file_size: 1_048_576,
          total_chunks: 1
        })

      {:ok, _transfer} = Transfers.update_transfer(transfer, %{status: "completed"})

      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify transfer is displayed
      assert html =~ "test-file.pdf"
      assert html =~ "1.0 MB"
      assert html =~ "completed"
    end

    test "displays transfer with correct file type icon", %{conn: conn, user: user} do
      # Create transfers with different file types
      {:ok, _pdf} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "document.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _image} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "photo.jpg",
          file_size: 2048,
          total_chunks: 1
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify both transfers are displayed
      assert html =~ "document.pdf"
      assert html =~ "photo.jpg"
    end

    test "formats file sizes correctly", %{conn: conn, user: user} do
      # Create transfers with different file sizes
      {:ok, _bytes} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "small.txt",
          file_size: 512,
          total_chunks: 1
        })

      {:ok, _kb} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "medium.txt",
          file_size: 1024 * 50,
          total_chunks: 1
        })

      {:ok, _mb} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "large.txt",
          file_size: 1_048_576 * 5,
          total_chunks: 1
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify file sizes are formatted
      assert html =~ "512 B"
      assert html =~ "50.0 KB"
      assert html =~ "5.0 MB"
    end

    test "displays formatted upload date", %{conn: conn, user: user} do
      # Create a transfer
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify date is formatted (format: "Mon DD, YYYY at HH:MM AM/PM")
      formatted_date = Calendar.strftime(transfer.inserted_at, "%b %d, %Y at %I:%M %p")
      assert html =~ formatted_date
    end

    test "displays action buttons for each transfer", %{conn: conn, user: user} do
      {:ok, _transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Verify action buttons are present
      assert has_element?(view, "button[phx-click='download']")
      assert has_element?(view, "button[phx-click='share']")
      assert has_element?(view, "button[phx-click='delete']")
    end
  end

  describe "filtering" do
    setup %{user: user} do
      # Create transfers with different statuses
      {:ok, completed1} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "completed1.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _completed1} = Transfers.update_transfer(completed1, %{status: "completed"})

      {:ok, completed2} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "completed2.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _completed2} = Transfers.update_transfer(completed2, %{status: "completed"})

      {:ok, _pending} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "pending.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, failed} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "failed.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _failed} = Transfers.update_transfer(failed, %{status: "failed"})

      :ok
    end

    test "filter by all shows all transfers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers?filter=all")

      # All transfers should be visible
      assert html =~ "completed1.pdf"
      assert html =~ "completed2.pdf"
      assert html =~ "pending.pdf"
      assert html =~ "failed.pdf"
    end

    test "filter by completed shows only completed transfers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers?filter=completed")

      # Only completed transfers should be visible
      assert html =~ "completed1.pdf"
      assert html =~ "completed2.pdf"
      refute html =~ "pending.pdf"
      refute html =~ "failed.pdf"
    end

    test "filter by pending shows only pending transfers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers?filter=pending")

      # Only pending transfers should be visible
      assert html =~ "pending.pdf"
      refute html =~ "completed1.pdf"
      refute html =~ "completed2.pdf"
      refute html =~ "failed.pdf"
    end

    test "filter by failed shows only failed transfers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers?filter=failed")

      # Only failed transfers should be visible
      assert html =~ "failed.pdf"
      refute html =~ "completed1.pdf"
      refute html =~ "completed2.pdf"
      refute html =~ "pending.pdf"
    end

    test "active filter button has correct styling", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers?filter=completed")

      # The completed filter button should have active styling
      # This checks for the active class combination
      assert html =~ "bg-blue-100 text-blue-700"
    end

    test "clicking filter button updates URL and filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Click on completed filter
      view
      |> element("a[href='/dashboard/transfers?filter=completed']")
      |> render_click()

      # Verify only completed transfers are shown
      html = render(view)
      assert html =~ "completed1.pdf"
      refute html =~ "pending.pdf"
    end
  end

  describe "search" do
    setup %{user: user} do
      # Create transfers with different names
      {:ok, _invoice} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "invoice-2024.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _photo} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "vacation-photo.jpg",
          file_size: 2048,
          total_chunks: 1
        })

      {:ok, _report} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "annual-report.docx",
          file_size: 3072,
          total_chunks: 1
        })

      :ok
    end

    test "search finds matching transfers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Search for "invoice"
      view
      |> form("form[phx-submit='search']", %{search: "invoice"})
      |> render_submit()

      html = render(view)

      # Only invoice should be visible
      assert html =~ "invoice-2024.pdf"
      refute html =~ "vacation-photo.jpg"
      refute html =~ "annual-report.docx"
    end

    test "search is case-insensitive", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Search with uppercase
      view
      |> form("form[phx-submit='search']", %{search: "PHOTO"})
      |> render_submit()

      html = render(view)

      # Should find vacation-photo.jpg
      assert html =~ "vacation-photo.jpg"
    end

    test "search returns no results when no match", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Search for something that doesn't exist
      view
      |> form("form[phx-submit='search']", %{search: "nonexistent"})
      |> render_submit()

      html = render(view)

      # Should show empty state with adjusted message
      assert html =~ "No transfers found"
      assert html =~ "Try adjusting your filters or search query"
    end

    test "clearing search shows all transfers again", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # First search for something
      view
      |> form("form[phx-submit='search']", %{search: "invoice"})
      |> render_submit()

      # Then clear the search
      view
      |> form("form[phx-submit='search']", %{search: ""})
      |> render_submit()

      html = render(view)

      # All transfers should be visible again
      assert html =~ "invoice-2024.pdf"
      assert html =~ "vacation-photo.jpg"
      assert html =~ "annual-report.docx"
    end

    test "search works with filters combined", %{conn: conn, user: user} do
      # Create a completed transfer with searchable name
      {:ok, completed} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "completed-invoice.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _completed} = Transfers.update_transfer(completed, %{status: "completed"})

      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers?filter=completed")

      # Search within completed filter
      view
      |> form("form[phx-submit='search']", %{search: "invoice"})
      |> render_submit()

      html = render(view)

      # Should find the completed invoice
      assert html =~ "completed-invoice.pdf"
      # But not the pending invoice
      refute html =~ "invoice-2024.pdf"
    end
  end

  describe "actions" do
    test "download button shows flash message", %{conn: conn, user: user} do
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Click download button
      html =
        view
        |> element("button[phx-click='download'][phx-value-id='#{transfer.id}']")
        |> render_click()

      # Verify flash message appears
      assert html =~ "Preparing download for transfer"
    end

    test "share button navigates to create share page", %{conn: conn, user: user} do
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Click share button
      view
      |> element("button[phx-click='share'][phx-value-id='#{transfer.id}']")
      |> render_click()

      # Verify navigation to shares/new with transfer_id
      assert_redirect(view, ~p"/dashboard/shares/new?transfer_id=#{transfer.id}")
    end

    test "delete button removes transfer", %{conn: conn, user: user} do
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, view, _html} = live(conn, ~p"/dashboard/transfers")

      # Click delete button (bypassing confirmation dialog in tests)
      html =
        view
        |> element("button[phx-click='delete'][phx-value-id='#{transfer.id}']")
        |> render_click()

      # Verify success message
      assert html =~ "Transfer deleted successfully"

      # Verify transfer is no longer displayed
      refute html =~ "test.pdf"
    end
  end

  describe "status badges" do
    test "completed transfers have green badge", %{conn: conn, user: user} do
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _transfer} = Transfers.update_transfer(transfer, %{status: "completed"})

      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify completed status has green badge
      assert html =~ "bg-green-100 text-green-700"
      assert html =~ "completed"
    end

    test "pending transfers have yellow badge", %{conn: conn, user: user} do
      {:ok, _transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify pending status has yellow badge
      assert html =~ "bg-yellow-100 text-yellow-700"
      assert html =~ "pending"
    end

    test "failed transfers have red badge", %{conn: conn, user: user} do
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _transfer} = Transfers.update_transfer(transfer, %{status: "failed"})

      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify failed status has red badge
      assert html =~ "bg-red-100 text-red-700"
      assert html =~ "failed"
    end

    test "processing transfers have blue badge", %{conn: conn, user: user} do
      {:ok, transfer} =
        Transfers.create_transfer(%{
          user_id: user.id,
          file_name: "test.pdf",
          file_size: 1024,
          total_chunks: 1
        })

      {:ok, _transfer} = Transfers.update_transfer(transfer, %{status: "processing"})

      {:ok, _view, html} = live(conn, ~p"/dashboard/transfers")

      # Verify processing status has blue badge
      assert html =~ "bg-blue-100 text-blue-700"
      assert html =~ "processing"
    end
  end

  describe "authentication" do
    test "non-authenticated user cannot access transfers page" do
      # Create a new connection without authentication
      conn = build_conn()

      # Try to access transfers page - should redirect to login
      assert {:error, {:redirect, redirect_info}} = live(conn, ~p"/dashboard/transfers")
      assert redirect_info.to == "/login"
    end
  end
end
