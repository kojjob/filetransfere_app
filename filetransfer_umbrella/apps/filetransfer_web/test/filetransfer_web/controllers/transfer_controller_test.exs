defmodule FiletransferWeb.TransferControllerTest do
  use FiletransferWeb.ConnCase
  alias FiletransferCore.Transfers
  alias FiletransferWeb.Fixtures

  describe "POST /api/transfers" do
    test "creates a new transfer with valid params", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      transfer_params = %{
        "transfer" => %{
          "file_name" => "document.pdf",
          "file_size" => 10_485_760,
          "file_type" => "application/pdf"
        }
      }

      conn = post(conn, ~p"/api/transfers", transfer_params)
      assert %{"status" => "success"} = json_response(conn, 201)
      assert %{"data" => data} = json_response(conn, 201)
      assert data["id"] != nil
      assert data["file_name"] == "document.pdf"
      assert data["file_size"] == 10_485_760
      assert data["status"] == "pending"
      assert data["total_chunks"] > 0
    end

    test "requires authentication", %{conn: conn} do
      transfer_params = %{
        "transfer" => %{
          "file_name" => "document.pdf",
          "file_size" => 10_485_760,
          "file_type" => "application/pdf"
        }
      }

      conn = post(conn, ~p"/api/transfers", transfer_params)

      assert json_response(conn, 401) == %{
               "status" => "error",
               "message" => "Authentication required"
             }
    end

    test "returns error with invalid params", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      transfer_params = %{
        "transfer" => %{
          "file_name" => "",
          "file_size" => -1
        }
      }

      conn = post(conn, ~p"/api/transfers", transfer_params)
      assert %{"status" => "error"} = json_response(conn, 422)
      assert %{"errors" => _errors} = json_response(conn, 422)
    end

    test "calculates correct number of chunks", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      # 10MB file with 5MB chunks = 2 chunks
      transfer_params = %{
        "transfer" => %{
          "file_name" => "test.pdf",
          "file_size" => 10_485_760,
          "file_type" => "application/pdf"
        }
      }

      conn = post(conn, ~p"/api/transfers", transfer_params)
      assert %{"data" => data} = json_response(conn, 201)
      assert data["total_chunks"] == 2
    end
  end

  describe "GET /api/transfers" do
    test "lists user's transfers", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      # Create transfers for this user
      _transfer1 = Fixtures.transfer_fixture(user, %{file_name: "file1.pdf"})
      _transfer2 = Fixtures.transfer_fixture(user, %{file_name: "file2.pdf"})

      # Create transfer for another user (should not appear)
      other_user = Fixtures.user_fixture()
      _other_transfer = Fixtures.transfer_fixture(other_user, %{file_name: "other.pdf"})

      conn = get(conn, ~p"/api/transfers")
      assert %{"status" => "success"} = json_response(conn, 200)
      assert %{"data" => transfers} = json_response(conn, 200)
      assert length(transfers) == 2
      assert Enum.all?(transfers, &(&1["user_id"] == user.id))
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/transfers")

      assert json_response(conn, 401) == %{
               "status" => "error",
               "message" => "Authentication required"
             }
    end

    test "returns empty list when user has no transfers", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      conn = get(conn, ~p"/api/transfers")
      assert %{"status" => "success"} = json_response(conn, 200)
      assert %{"data" => transfers} = json_response(conn, 200)
      assert transfers == []
    end
  end

  describe "GET /api/transfers/:id" do
    test "returns transfer details", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      transfer =
        Fixtures.transfer_fixture(user, %{
          file_name: "test.pdf",
          file_size: 10_485_760
        })

      conn = get(conn, ~p"/api/transfers/#{transfer.id}")
      assert %{"status" => "success"} = json_response(conn, 200)
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == transfer.id
      assert data["file_name"] == "test.pdf"
      assert data["file_size"] == 10_485_760
      assert data["chunks"] != nil
    end

    test "requires authentication", %{conn: conn} do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user)

      conn = get(conn, ~p"/api/transfers/#{transfer.id}")

      assert json_response(conn, 401) == %{
               "status" => "error",
               "message" => "Authentication required"
             }
    end

    test "returns 404 for non-existent transfer", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/transfers/#{fake_id}")
      assert json_response(conn, 404) == %{"status" => "error", "message" => "Transfer not found"}
    end

    test "returns 403 for other user's transfer", %{conn: conn} do
      user1 = Fixtures.user_fixture()
      user2 = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user1)

      transfer = Fixtures.transfer_fixture(user2)

      conn = get(conn, ~p"/api/transfers/#{transfer.id}")
      assert json_response(conn, 403) == %{"status" => "error", "message" => "Not authorized"}
    end
  end

  describe "POST /api/transfers/:id/chunks/:index" do
    test "updates chunk progress", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      transfer = Fixtures.transfer_fixture(user, %{file_size: 10_485_760})

      chunk_params = %{
        # Half of 5MB chunk
        "bytes_uploaded" => 2_621_440
      }

      conn = post(conn, ~p"/api/transfers/#{transfer.id}/chunks/0", chunk_params)
      assert %{"status" => "success"} = json_response(conn, 200)
      assert %{"data" => data} = json_response(conn, 200)
      assert data["bytes_uploaded"] == 2_621_440
      assert data["status"] == "uploading"
    end

    test "marks chunk as completed when fully uploaded", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      transfer = Fixtures.transfer_fixture(user, %{file_size: 10_485_760})

      chunk_params = %{
        # Full 5MB chunk
        "bytes_uploaded" => 5_242_880
      }

      conn = post(conn, ~p"/api/transfers/#{transfer.id}/chunks/0", chunk_params)
      assert %{"status" => "success"} = json_response(conn, 200)
      assert %{"data" => data} = json_response(conn, 200)
      assert data["bytes_uploaded"] == 5_242_880
      assert data["status"] == "completed"
    end

    test "requires authentication", %{conn: conn} do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user)

      chunk_params = %{"bytes_uploaded" => 1000}

      conn = post(conn, ~p"/api/transfers/#{transfer.id}/chunks/0", chunk_params)

      assert json_response(conn, 401) == %{
               "status" => "error",
               "message" => "Authentication required"
             }
    end

    test "returns 404 for non-existent transfer", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      fake_id = Ecto.UUID.generate()
      chunk_params = %{"bytes_uploaded" => 1000}

      conn = post(conn, ~p"/api/transfers/#{fake_id}/chunks/0", chunk_params)
      assert json_response(conn, 404) == %{"status" => "error", "message" => "Transfer not found"}
    end

    test "returns 403 for other user's transfer", %{conn: conn} do
      user1 = Fixtures.user_fixture()
      user2 = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user1)

      transfer = Fixtures.transfer_fixture(user2)
      chunk_params = %{"bytes_uploaded" => 1000}

      conn = post(conn, ~p"/api/transfers/#{transfer.id}/chunks/0", chunk_params)
      assert json_response(conn, 403) == %{"status" => "error", "message" => "Not authorized"}
    end
  end

  describe "GET /api/transfers/:id/resume" do
    test "returns incomplete chunks for resuming", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      transfer = Fixtures.transfer_fixture(user, %{file_size: 10_485_760})

      # Mark first chunk as completed
      Transfers.update_chunk_progress(transfer.id, 0, 5_242_880)

      conn = get(conn, ~p"/api/transfers/#{transfer.id}/resume")
      assert %{"status" => "success"} = json_response(conn, 200)
      assert %{"data" => chunks} = json_response(conn, 200)
      # Only one incomplete chunk
      assert length(chunks) == 1
      assert Enum.at(chunks, 0)["chunk_index"] == 1
    end

    test "requires authentication", %{conn: conn} do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user)

      conn = get(conn, ~p"/api/transfers/#{transfer.id}/resume")

      assert json_response(conn, 401) == %{
               "status" => "error",
               "message" => "Authentication required"
             }
    end

    test "returns 404 for non-existent transfer", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/api/transfers/#{fake_id}/resume")
      assert json_response(conn, 404) == %{"status" => "error", "message" => "Transfer not found"}
    end

    test "returns 403 for other user's transfer", %{conn: conn} do
      user1 = Fixtures.user_fixture()
      user2 = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user1)

      transfer = Fixtures.transfer_fixture(user2)

      conn = get(conn, ~p"/api/transfers/#{transfer.id}/resume")
      assert json_response(conn, 403) == %{"status" => "error", "message" => "Not authorized"}
    end
  end

  describe "DELETE /api/transfers/:id" do
    test "deletes user's transfer", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      transfer = Fixtures.transfer_fixture(user)

      conn = delete(conn, ~p"/api/transfers/#{transfer.id}")
      assert %{"status" => "success"} = json_response(conn, 200)
      assert %{"message" => _} = json_response(conn, 200)

      # Verify transfer is deleted
      assert_raise Ecto.NoResultsError, fn ->
        Transfers.get_transfer!(transfer.id)
      end
    end

    test "requires authentication", %{conn: conn} do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user)

      conn = delete(conn, ~p"/api/transfers/#{transfer.id}")

      assert json_response(conn, 401) == %{
               "status" => "error",
               "message" => "Authentication required"
             }
    end

    test "returns 404 for non-existent transfer", %{conn: conn} do
      user = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user)

      fake_id = Ecto.UUID.generate()

      conn = delete(conn, ~p"/api/transfers/#{fake_id}")
      assert json_response(conn, 404) == %{"status" => "error", "message" => "Transfer not found"}
    end

    test "returns 403 for other user's transfer", %{conn: conn} do
      user1 = Fixtures.user_fixture()
      user2 = Fixtures.user_fixture()
      conn = Fixtures.authenticate_user(conn, user1)

      transfer = Fixtures.transfer_fixture(user2)

      conn = delete(conn, ~p"/api/transfers/#{transfer.id}")
      assert json_response(conn, 403) == %{"status" => "error", "message" => "Not authorized"}
    end
  end
end
