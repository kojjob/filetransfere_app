defmodule FiletransferWeb.Fixtures do
  @moduledoc """
  Test fixtures for creating test data.
  """

  alias FiletransferCore.{Accounts, Transfers}

  @doc """
  Creates a user for testing.
  """
  def user_fixture(attrs \\ %{}) do
    unique_id = :erlang.unique_integer([:positive, :monotonic])
    timestamp = System.system_time(:microsecond)

    default_attrs = %{
      email: "user#{unique_id}_#{timestamp}@example.com",
      name: "Test User",
      password: "Password123!"
    }

    attrs = Enum.into(attrs, default_attrs)

    case Accounts.create_user(attrs) do
      {:ok, user} -> user
      {:error, changeset} -> raise "Failed to create user: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Creates a transfer for testing.
  """
  def transfer_fixture(user, attrs \\ %{}) do
    default_attrs = %{
      file_name: "test_file.pdf",
      # 10MB
      file_size: 10_485_760,
      file_type: "application/pdf",
      user_id: user.id
    }

    attrs = Enum.into(attrs, default_attrs)

    {:ok, transfer} = Transfers.create_transfer(attrs)
    transfer
  end

  @doc """
  Authenticates a user in the connection for testing.
  """
  def authenticate_user(conn, user) do
    conn
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
