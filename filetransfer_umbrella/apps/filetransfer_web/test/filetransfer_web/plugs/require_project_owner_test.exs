defmodule FiletransferWeb.Plugs.RequireProjectOwnerTest do
  use FiletransferWeb.ConnCase, async: true

  alias FiletransferWeb.Plugs.RequireProjectOwner

  describe "call/2" do
    test "allows project owner to proceed", %{conn: conn} do
      project_owner = project_owner_fixture()

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> authenticate_and_assign_user(project_owner)
        |> RequireProjectOwner.call([])

      refute conn.halted
      assert conn.status != 403
    end

    test "blocks regular user with 403 forbidden", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> authenticate_and_assign_user(user)
        |> RequireProjectOwner.call([])

      assert conn.halted
      assert conn.status == 403
    end

    test "blocks unauthenticated request with 401 unauthorized", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> RequireProjectOwner.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "returns JSON error for API requests from regular user", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> authenticate_and_assign_user(user)
        |> RequireProjectOwner.call([])

      assert conn.halted
      assert conn.status == 403
      response = json_response(conn, 403)
      assert response["status"] == "error"
      assert response["message"] =~ "Access denied"
    end

    test "returns JSON error for API requests without authentication", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> RequireProjectOwner.call([])

      assert conn.halted
      assert conn.status == 401
      response = json_response(conn, 401)
      assert response["status"] == "error"
      assert response["message"] =~ "Authentication required"
    end
  end

  describe "init/1" do
    test "returns opts unchanged" do
      assert RequireProjectOwner.init(foo: :bar) == [foo: :bar]
    end
  end
end
