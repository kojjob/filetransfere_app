defmodule FiletransferWeb.UserSocket do
  @moduledoc """
  Phoenix Socket for user channel connections.

  Handles authentication and user identification for
  real-time WebSocket connections.
  """
  use Phoenix.Socket

  # Channels
  channel "transfer:*", FiletransferWeb.TransferChannel

  @doc """
  Socket connect callback.

  Authenticates the user from the socket params. In production,
  this should use token-based authentication.

  ## Parameters

    * `params` - Connection parameters containing user identification
    * `socket` - The socket to be connected

  ## Returns

    * `{:ok, socket}` - Connection accepted with user_id assigned
    * `:error` - Connection rejected

  """
  @impl true
  def connect(%{"user_id" => user_id}, socket, _connect_info) when is_integer(user_id) do
    {:ok, assign(socket, :user_id, user_id)}
  end

  def connect(%{"user_id" => user_id}, socket, _connect_info) when is_binary(user_id) do
    {:ok, assign(socket, :user_id, user_id)}
  end

  def connect(_params, socket, _connect_info) do
    # Allow connection but without authenticated user
    {:ok, assign(socket, :user_id, nil)}
  end

  @doc """
  Returns unique identifier for this socket.

  Used for per-socket state tracking. Returns nil for
  unauthenticated connections.
  """
  @impl true
  def id(socket) do
    case socket.assigns[:user_id] do
      nil -> nil
      user_id -> "user_socket:#{user_id}"
    end
  end
end
