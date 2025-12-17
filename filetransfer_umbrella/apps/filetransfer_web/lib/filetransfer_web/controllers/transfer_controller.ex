defmodule FiletransferWeb.TransferController do
  use FiletransferWeb, :controller
  alias FiletransferCore.Transfers
  alias FiletransferCore.Transfers.Transfer

  def index(conn, _params) do
    user = conn.assigns.current_user
    transfers = Transfers.list_transfers(user.id)

    json(conn, %{
      status: "success",
      data: Enum.map(transfers, &format_transfer/1)
    })
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Transfers.get_user_transfer(user.id, id) do
      nil ->
        # Check if transfer exists but belongs to another user
        try do
          transfer = Transfers.get_transfer!(id)

          if transfer.user_id != user.id do
            conn
            |> put_status(:forbidden)
            |> json(%{status: "error", message: "Not authorized"})
          else
            conn
            |> put_status(:not_found)
            |> json(%{status: "error", message: "Transfer not found"})
          end
        rescue
          Ecto.NoResultsError ->
            conn
            |> put_status(:not_found)
            |> json(%{status: "error", message: "Transfer not found"})
        end

      transfer ->
        json(conn, %{
          status: "success",
          data: format_transfer(transfer)
        })
    end
  end

  def create(conn, %{"transfer" => transfer_params}) do
    user = conn.assigns.current_user

    file_size =
      case Map.get(transfer_params, "file_size") do
        size when is_binary(size) -> String.to_integer(size)
        size when is_integer(size) -> size
        _ -> 0
      end

    # Convert string keys to atom keys for Ecto
    attrs =
      transfer_params
      |> Map.put("user_id", user.id)
      |> Map.put("file_name", Map.get(transfer_params, "file_name", "untitled"))
      |> Map.put("file_size", file_size)
      |> Map.put("file_type", Map.get(transfer_params, "file_type"))
      |> atomize_keys()

    case Transfers.create_transfer(attrs) do
      {:ok, transfer} ->
        conn
        |> put_status(:created)
        |> json(%{
          status: "success",
          data: format_transfer(transfer)
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          status: "error",
          errors: translate_errors(changeset)
        })
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Transfers.get_user_transfer(user.id, id) do
      nil ->
        # Check if transfer exists but belongs to another user
        try do
          transfer = Transfers.get_transfer!(id)

          if transfer.user_id != user.id do
            conn
            |> put_status(:forbidden)
            |> json(%{status: "error", message: "Not authorized"})
          else
            conn
            |> put_status(:not_found)
            |> json(%{status: "error", message: "Transfer not found"})
          end
        rescue
          Ecto.NoResultsError ->
            conn
            |> put_status(:not_found)
            |> json(%{status: "error", message: "Transfer not found"})
        end

      transfer ->
        Transfers.delete_transfer(transfer)
        json(conn, %{status: "success", message: "Transfer deleted"})
    end
  end

  def update_chunk(conn, %{"id" => transfer_id, "index" => chunk_index} = params) do
    user = conn.assigns.current_user

    case Transfers.get_user_transfer(user.id, transfer_id) do
      nil ->
        # Check if transfer exists but belongs to another user
        try do
          transfer = Transfers.get_transfer!(transfer_id)

          if transfer.user_id != user.id do
            conn
            |> put_status(:forbidden)
            |> json(%{status: "error", message: "Not authorized"})
          else
            conn
            |> put_status(:not_found)
            |> json(%{status: "error", message: "Transfer not found"})
          end
        rescue
          Ecto.NoResultsError ->
            conn
            |> put_status(:not_found)
            |> json(%{status: "error", message: "Transfer not found"})
        end

      transfer ->
        chunk_index = String.to_integer(chunk_index)
        # Accept params directly or nested under "chunk"
        chunk_params = Map.get(params, "chunk", params)
        bytes_uploaded = parse_bytes_uploaded(chunk_params)

        Transfers.update_chunk_progress(transfer.id, chunk_index, bytes_uploaded)

        # Refetch transfer to get updated chunk
        updated_transfer = Transfers.get_transfer!(transfer.id)
        chunk = Enum.find(updated_transfer.chunks, &(&1.chunk_index == chunk_index))

        if chunk do
          json(conn, %{
            status: "success",
            data: format_chunk(chunk)
          })
        else
          conn
          |> put_status(:not_found)
          |> json(%{status: "error", message: "Chunk not found"})
        end
    end
  end

  def resume(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Transfers.get_user_transfer(user.id, id) do
      nil ->
        # Check if transfer exists but belongs to another user
        try do
          transfer = Transfers.get_transfer!(id)

          if transfer.user_id != user.id do
            conn
            |> put_status(:forbidden)
            |> json(%{status: "error", message: "Not authorized"})
          else
            conn
            |> put_status(:not_found)
            |> json(%{status: "error", message: "Transfer not found"})
          end
        rescue
          Ecto.NoResultsError ->
            conn
            |> put_status(:not_found)
            |> json(%{status: "error", message: "Transfer not found"})
        end

      transfer ->
        incomplete_chunks = Transfers.get_incomplete_chunks(transfer.id)

        json(conn, %{
          status: "success",
          data: Enum.map(incomplete_chunks, &format_chunk/1)
        })
    end
  end

  defp parse_bytes_uploaded(chunk_params) do
    case Map.get(chunk_params, "bytes_uploaded") do
      bytes when is_binary(bytes) -> String.to_integer(bytes)
      bytes when is_integer(bytes) -> bytes
      _ -> 0
    end
  end

  defp format_chunk(chunk) do
    %{
      id: chunk.id,
      chunk_index: chunk.chunk_index,
      chunk_size: chunk.chunk_size,
      bytes_uploaded: chunk.bytes_uploaded,
      status: chunk.status,
      transfer_id: chunk.transfer_id
    }
  end

  defp format_transfer(%Transfer{} = transfer) do
    %{
      id: transfer.id,
      user_id: transfer.user_id,
      file_name: transfer.file_name,
      file_size: transfer.file_size,
      file_type: transfer.file_type,
      status: transfer.status,
      total_chunks: transfer.total_chunks,
      uploaded_chunks: transfer.uploaded_chunks,
      bytes_uploaded: transfer.bytes_uploaded,
      progress: calculate_progress(transfer),
      chunk_size: transfer.chunk_size,
      chunks: Enum.map(transfer.chunks || [], &format_chunk/1),
      created_at: transfer.inserted_at,
      started_at: transfer.started_at,
      completed_at: transfer.completed_at
    }
  end

  defp calculate_progress(%Transfer{} = transfer) do
    if transfer.file_size > 0 do
      Float.round(transfer.bytes_uploaded / transfer.file_size * 100, 2)
    else
      0.0
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp atomize_keys(map) do
    for {key, value} <- map, into: %{} do
      case key do
        k when is_binary(k) ->
          atom_key =
            case k do
              "user_id" -> :user_id
              "file_name" -> :file_name
              "file_size" -> :file_size
              "file_type" -> :file_type
              "chunk_size" -> :chunk_size
              _ -> String.to_atom(k)
            end

          {atom_key, value}

        k ->
          {k, value}
      end
    end
  end
end
