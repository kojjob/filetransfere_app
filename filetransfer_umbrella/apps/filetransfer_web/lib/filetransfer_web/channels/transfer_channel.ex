defmodule FiletransferWeb.TransferChannel do
  @moduledoc """
  Phoenix Channel for real-time file transfer progress tracking.

  This channel enables clients to:
  - Subscribe to transfer updates
  - Report chunk upload progress
  - Receive real-time progress broadcasts
  - Get speed and ETA calculations

  ## Usage

  ```javascript
  // Connect to socket
  const socket = new Socket("/socket", {params: {user_id: userId}})
  socket.connect()

  // Join transfer channel
  const channel = socket.channel(`transfer:${transferId}`, {})
  channel.join()
    .receive("ok", resp => console.log("Joined", resp))
    .receive("error", resp => console.log("Error joining", resp))

  // Listen for progress updates
  channel.on("transfer:progress", payload => {
    console.log("Progress:", payload.progress_percent)
    console.log("Speed:", payload.speed_bytes_per_sec)
    console.log("ETA:", payload.eta_seconds)
  })

  // Report chunk progress
  channel.push("chunk:progress", {
    chunk_index: 0,
    bytes_uploaded: 1048576,
    timestamp: Date.now()
  })
  ```
  """
  use Phoenix.Channel

  alias FiletransferCore.Transfers
  alias FiletransferWeb.Endpoint

  require Logger

  # Store last progress update for speed calculation
  @progress_state_key :progress_state

  @doc """
  Handles client joining a transfer channel.

  Validates that:
  - The user is authenticated
  - The transfer exists
  - The user owns the transfer

  ## Returns

    * `{:ok, socket}` - Join successful
    * `{:error, %{reason: reason}}` - Join rejected
  """
  @impl true
  def join("transfer:" <> transfer_id, _params, socket) do
    user_id = socket.assigns[:user_id]

    cond do
      is_nil(user_id) ->
        {:error, %{reason: "unauthorized"}}

      true ->
        case Transfers.get_user_transfer(user_id, transfer_id) do
          nil ->
            # Check if transfer exists at all for better error message
            case Transfers.get_transfer(transfer_id) do
              {:ok, _} -> {:error, %{reason: "unauthorized"}}
              {:error, :not_found} -> {:error, %{reason: "not_found"}}
            end

          transfer ->
            socket =
              socket
              |> assign(:transfer_id, transfer.id)
              |> assign(:transfer, transfer)
              |> assign(@progress_state_key, init_progress_state(transfer))

            send(self(), :after_join)
            {:ok, socket}
        end
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    transfer = socket.assigns.transfer

    push(socket, "transfer:joined", %{
      transfer_id: transfer.id,
      file_name: transfer.file_name,
      file_size: transfer.file_size,
      total_chunks: transfer.total_chunks,
      status: transfer.status,
      bytes_uploaded: transfer.bytes_uploaded || 0
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("chunk:progress", payload, socket) do
    %{
      "chunk_index" => chunk_index,
      "bytes_uploaded" => bytes_uploaded
    } = payload

    transfer = socket.assigns.transfer
    timestamp = Map.get(payload, "timestamp", System.system_time(:millisecond))

    # Update progress in database
    case Transfers.update_chunk_progress(transfer.id, chunk_index, bytes_uploaded) do
      {:ok, updated_transfer} ->
        # Calculate speed and ETA
        progress_state = socket.assigns[@progress_state_key]

        {speed, eta, new_state} =
          calculate_speed_and_eta(progress_state, updated_transfer, timestamp)

        # Determine chunk status
        chunk = Enum.find(updated_transfer.chunks, &(&1.chunk_index == chunk_index))
        chunk_completed = chunk && chunk.status == "completed"

        # Broadcast progress
        progress_payload = %{
          transfer_id: transfer.id,
          chunk_index: chunk_index,
          bytes_uploaded: bytes_uploaded,
          total_bytes_uploaded: updated_transfer.bytes_uploaded || 0,
          progress_percent: calculate_progress_percent(updated_transfer),
          speed_bytes_per_sec: speed,
          eta_seconds: eta
        }

        broadcast!(socket, "transfer:progress", progress_payload)

        # Broadcast chunk completion if applicable
        if chunk_completed do
          broadcast!(socket, "chunk:completed", %{
            chunk_index: chunk_index,
            status: "completed"
          })
        end

        socket = assign(socket, @progress_state_key, new_state)
        socket = assign(socket, :transfer, updated_transfer)
        {:noreply, socket}

      {:error, _reason} ->
        {:reply, {:error, %{reason: "failed_to_update"}}, socket}
    end
  end

  @impl true
  def handle_in("chunk:complete", %{"chunk_index" => chunk_index}, socket) do
    transfer = socket.assigns.transfer

    # Mark chunk as complete in database
    chunk = Enum.find(transfer.chunks, &(&1.chunk_index == chunk_index))

    if chunk do
      Transfers.update_chunk_progress(transfer.id, chunk_index, chunk.chunk_size)
    end

    # Refresh transfer
    updated_transfer = Transfers.get_transfer!(transfer.id)

    # Check if all chunks are complete
    all_complete = Enum.all?(updated_transfer.chunks, &(&1.status == "completed"))

    if all_complete do
      {:ok, completed_transfer} =
        Transfers.update_transfer(updated_transfer, %{status: "completed"})

      broadcast!(socket, "transfer:complete", %{
        transfer_id: transfer.id,
        status: "completed",
        completed_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      socket = assign(socket, :transfer, completed_transfer)
      {:noreply, socket}
    else
      socket = assign(socket, :transfer, updated_transfer)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_in("transfer:cancel", _payload, socket) do
    transfer = socket.assigns.transfer

    case Transfers.update_transfer(transfer, %{status: "cancelled"}) do
      {:ok, _} ->
        broadcast!(socket, "transfer:cancelled", %{
          transfer_id: transfer.id,
          status: "cancelled"
        })

        {:stop, :normal, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "failed_to_cancel"}}, socket}
    end
  end

  # Public API for broadcasting from other parts of the application

  @doc """
  Broadcasts progress update to all subscribers of a transfer channel.

  Can be called from controllers or other processes to notify
  channel subscribers of progress updates.

  ## Parameters

    * `transfer_id` - The ID of the transfer
    * `chunk_index` - The index of the chunk being updated
    * `bytes_uploaded` - Number of bytes uploaded for this chunk

  ## Example

      TransferChannel.broadcast_progress(transfer_id, 0, 2_621_440)
  """
  def broadcast_progress(transfer_id, chunk_index, bytes_uploaded) do
    transfer = Transfers.get_transfer!(transfer_id)

    payload = %{
      transfer_id: transfer_id,
      chunk_index: chunk_index,
      bytes_uploaded: bytes_uploaded,
      total_bytes_uploaded: transfer.bytes_uploaded || 0,
      progress_percent: calculate_progress_percent(transfer)
    }

    Endpoint.broadcast("transfer:#{transfer_id}", "transfer:progress", payload)
  end

  @doc """
  Broadcasts transfer completion to all subscribers.
  """
  def broadcast_complete(transfer_id) do
    Endpoint.broadcast("transfer:#{transfer_id}", "transfer:complete", %{
      transfer_id: transfer_id,
      status: "completed",
      completed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Broadcasts transfer failure to all subscribers.
  """
  def broadcast_error(transfer_id, error_message) do
    Endpoint.broadcast("transfer:#{transfer_id}", "transfer:error", %{
      transfer_id: transfer_id,
      status: "failed",
      error: error_message
    })
  end

  # Private helpers

  defp init_progress_state(transfer) do
    %{
      start_time: System.system_time(:millisecond),
      last_update_time: System.system_time(:millisecond),
      last_bytes_uploaded: transfer.bytes_uploaded || 0,
      samples: []
    }
  end

  defp calculate_progress_percent(transfer) do
    if transfer.file_size > 0 do
      bytes_uploaded = transfer.bytes_uploaded || 0
      Float.round(bytes_uploaded / transfer.file_size * 100, 2)
    else
      0.0
    end
  end

  defp calculate_speed_and_eta(state, transfer, current_time) do
    current_bytes = transfer.bytes_uploaded || 0
    time_diff = current_time - state.last_update_time
    bytes_diff = current_bytes - state.last_bytes_uploaded

    # Calculate instantaneous speed (bytes per second) - used for debugging
    _instant_speed =
      if time_diff > 0 do
        bytes_diff / time_diff * 1000
      else
        0
      end

    # Keep rolling window of samples for smoothed speed
    samples = [{current_time, current_bytes} | Enum.take(state.samples, 9)]

    # Calculate average speed from samples
    avg_speed = calculate_average_speed(samples)

    # Calculate ETA
    remaining_bytes = transfer.file_size - current_bytes

    eta =
      if avg_speed > 0 do
        Float.round(remaining_bytes / avg_speed, 0)
      else
        nil
      end

    new_state = %{
      state
      | last_update_time: current_time,
        last_bytes_uploaded: current_bytes,
        samples: samples
    }

    {Float.round(avg_speed, 2), eta, new_state}
  end

  defp calculate_average_speed(samples) when length(samples) < 2, do: 0.0

  defp calculate_average_speed(samples) do
    [{latest_time, latest_bytes} | _] = samples
    {oldest_time, oldest_bytes} = List.last(samples)

    time_diff = latest_time - oldest_time
    bytes_diff = latest_bytes - oldest_bytes

    if time_diff > 0 do
      bytes_diff / time_diff * 1000
    else
      0.0
    end
  end
end
