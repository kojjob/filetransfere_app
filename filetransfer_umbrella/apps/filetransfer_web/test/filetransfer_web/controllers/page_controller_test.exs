defmodule FiletransferWeb.PageControllerTest do
  use FiletransferWeb.ConnCase

  describe "GET /" do
    test "renders the ZipShare landing page", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Verify key landing page content
      assert response =~ "ZipShare"
      assert response =~ "Lightning Speed"
      assert response =~ "Join Waitlist"
    end

    test "includes hero section with key features", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Check stats section
      assert response =~ "10GB+"
      assert response =~ "256-bit"
      assert response =~ "AES Encryption"
    end

    test "includes features section", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Check feature cards
      assert response =~ "Large File Support"
      assert response =~ "Real-time Progress"
      assert response =~ "Resumable Transfers"
      assert response =~ "End-to-End Encryption"
    end

    test "includes waitlist form", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "waitlist-form"
      assert response =~ ~r/type="email"/
      assert response =~ "Email Address"
    end
  end
end
