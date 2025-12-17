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
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Transfer not found"})

      transfer ->
        json(conn, %{
          status: "success",
          data: format_transfer(transfer)
        })
    end
  end

  def create(conn, %{"transfer" => transfer_params}) do
    user = conn.assigns.current_user

    attrs =
      transfer_params
      |> Map.put("user_id", user.id)
      |> Map.put("file_name", Map.get(transfer_params, "file_name", "untitled"))
      |> Map.put("file_size", String.to_integer(Map.get(transfer_params, "file_size", "0")))
      |> Map.put("file_type", Map.get(transfer_params, "file_type"))

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
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Transfer not found"})

      transfer ->
        Transfers.delete_transfer(transfer)
        json(conn, %{status: "success", message: "Transfer deleted"})
    end
  end

  defp format_transfer(%Transfer{} = transfer) do
    %{
      id: transfer.id,
      file_name: transfer.file_name,
      file_size: transfer.file_size,
      file_type: transfer.file_type,
      status: transfer.status,
      total_chunks: transfer.total_chunks,
      uploaded_chunks: transfer.uploaded_chunks,
      bytes_uploaded: transfer.bytes_uploaded,
      progress: calculate_progress(transfer),
      chunk_size: transfer.chunk_size,
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
end
