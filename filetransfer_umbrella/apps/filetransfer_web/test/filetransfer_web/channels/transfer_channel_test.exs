defmodule FiletransferWeb.TransferChannelTest do
  use FiletransferWeb.ChannelCase

  alias FiletransferWeb.{UserSocket, TransferChannel}
  alias FiletransferWeb.Fixtures

  describe "join/3" do
    test "joins transfer channel successfully with valid user and transfer" do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user)

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      {:ok, _reply, _socket} =
        subscribe_and_join(socket, TransferChannel, "transfer:#{transfer.id}")

      assert_push "transfer:joined", %{transfer_id: transfer_id}
      assert transfer_id == transfer.id
    end

    test "rejects join when user doesn't own the transfer" do
      user1 = Fixtures.user_fixture()
      user2 = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user1)

      {:ok, socket} = connect(UserSocket, %{"user_id" => user2.id})

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, TransferChannel, "transfer:#{transfer.id}")
    end

    test "rejects join when transfer doesn't exist" do
      user = Fixtures.user_fixture()
      fake_id = Ecto.UUID.generate()

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      assert {:error, %{reason: "not_found"}} =
               subscribe_and_join(socket, TransferChannel, "transfer:#{fake_id}")
    end

    test "rejects join when user is not authenticated" do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user)

      {:ok, socket} = connect(UserSocket, %{})

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, TransferChannel, "transfer:#{transfer.id}")
    end
  end

  describe "handle_in progress_update" do
    test "updates chunk progress and broadcasts to channel" do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user, %{file_size: 10_485_760})

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, TransferChannel, "transfer:#{transfer.id}")

      # Send progress update
      push(socket, "chunk:progress", %{
        "chunk_index" => 0,
        "bytes_uploaded" => 2_621_440
      })

      # Should receive broadcast with progress
      assert_broadcast "transfer:progress", %{
        transfer_id: _,
        chunk_index: 0,
        bytes_uploaded: 2_621_440,
        total_bytes_uploaded: _,
        progress_percent: _
      }
    end

    test "marks chunk as completed when fully uploaded" do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user, %{file_size: 10_485_760})

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, TransferChannel, "transfer:#{transfer.id}")

      # Upload full chunk (5MB)
      push(socket, "chunk:progress", %{
        "chunk_index" => 0,
        "bytes_uploaded" => 5_242_880
      })

      assert_broadcast "chunk:completed", %{
        chunk_index: 0,
        status: "completed"
      }
    end
  end

  describe "handle_in chunk:complete" do
    test "broadcasts transfer:complete when all chunks are uploaded" do
      user = Fixtures.user_fixture()
      # Small file with just 1 chunk
      transfer = Fixtures.transfer_fixture(user, %{file_size: 1_000_000})

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, TransferChannel, "transfer:#{transfer.id}")

      # Complete the only chunk
      push(socket, "chunk:complete", %{
        "chunk_index" => 0
      })

      assert_broadcast "transfer:complete", %{
        transfer_id: _,
        status: "completed"
      }
    end
  end

  describe "broadcast_progress/3" do
    test "broadcasts progress to transfer channel" do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user, %{file_size: 10_485_760})

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      {:ok, _reply, _socket} =
        subscribe_and_join(socket, TransferChannel, "transfer:#{transfer.id}")

      # Broadcast progress via module function
      TransferChannel.broadcast_progress(transfer.id, 0, 2_621_440)

      assert_broadcast "transfer:progress", %{
        transfer_id: _,
        chunk_index: 0,
        bytes_uploaded: 2_621_440
      }
    end
  end

  describe "speed and ETA calculations" do
    test "includes speed and ETA in progress updates" do
      user = Fixtures.user_fixture()
      transfer = Fixtures.transfer_fixture(user, %{file_size: 10_485_760})

      {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, TransferChannel, "transfer:#{transfer.id}")

      # First progress update
      push(socket, "chunk:progress", %{
        "chunk_index" => 0,
        "bytes_uploaded" => 1_048_576,
        "timestamp" => System.system_time(:millisecond)
      })

      assert_broadcast "transfer:progress", payload

      # Should have speed/ETA info (may be 0 on first update)
      assert Map.has_key?(payload, :speed_bytes_per_sec)
      assert Map.has_key?(payload, :eta_seconds)
    end
  end
end
