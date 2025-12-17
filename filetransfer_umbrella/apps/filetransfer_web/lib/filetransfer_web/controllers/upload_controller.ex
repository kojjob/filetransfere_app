defmodule FiletransferWeb.UploadController do
  @moduledoc """
  Controller for handling file upload operations.
  """
  use FiletransferWeb, :controller

  alias FiletransferCore.{Transfers, Storage}
  alias FiletransferWeb.TransferChannel

  action_fallback FiletransferWeb.FallbackController

  def init_multipart(conn, %{"id" => transfer_id}) do
    user = conn.assigns.current_user
    with {:ok, transfer} <- get_user_transfer(user.id, transfer_id),
         key <- Storage.generate_key(user.id, transfer.id, transfer.file_name),
         {:ok, upload_id} <- Storage.initiate_multipart_upload(key, transfer.file_type) do
      {:ok, _} = Transfers.update_transfer(transfer, %{
        metadata: Map.put(transfer.metadata || %{}, "upload_id", upload_id),
        storage_path: key,
        status: "uploading"
      })
      json(conn, %{status: "success", data: %{upload_id: upload_id, key: key, transfer_id: transfer.id}})
    end
  end

  def upload_chunk(conn, %{"id" => transfer_id} = params) do
    user = conn.assigns.current_user
    part_number = parse_int(params["part_number"] || params["chunk_index"], 1)
    with {:ok, transfer} <- get_user_transfer(user.id, transfer_id),
         {:ok, upload_id} <- get_upload_id(transfer),
         {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, etag} <- Storage.upload_chunk(transfer.storage_path, upload_id, part_number, body) do
      bytes_uploaded = byte_size(body)
      {:ok, _updated} = Transfers.update_chunk_progress(transfer.id, part_number - 1, bytes_uploaded)
      TransferChannel.broadcast_progress(transfer.id, part_number - 1, bytes_uploaded)
      json(conn, %{status: "success", data: %{part_number: part_number, etag: etag, bytes_uploaded: bytes_uploaded}})
    end
  end

  def complete_upload(conn, %{"id" => transfer_id, "parts" => parts}) do
    user = conn.assigns.current_user
    with {:ok, transfer} <- get_user_transfer(user.id, transfer_id),
         {:ok, upload_id} <- get_upload_id(transfer),
         parts_list <- Enum.map(parts, fn p -> {parse_int(p["part_number"], 1), p["etag"]} end),
         {:ok, key} <- Storage.complete_multipart_upload(transfer.storage_path, upload_id, parts_list) do
      {:ok, _completed} = Transfers.update_transfer(transfer, %{status: "completed", completed_at: DateTime.utc_now()})
      TransferChannel.broadcast_complete(transfer.id)
      json(conn, %{status: "success", data: %{transfer_id: transfer.id, storage_path: key, status: "completed"}})
    end
  end

  def abort_upload(conn, %{"id" => transfer_id}) do
    user = conn.assigns.current_user
    with {:ok, transfer} <- get_user_transfer(user.id, transfer_id),
         {:ok, upload_id} <- get_upload_id(transfer),
         :ok <- Storage.abort_multipart_upload(transfer.storage_path, upload_id) do
      {:ok, _} = Transfers.update_transfer(transfer, %{status: "cancelled"})
      TransferChannel.broadcast_error(transfer.id, "Upload aborted")
      json(conn, %{status: "success", message: "Upload aborted"})
    end
  end

  def presigned_url(conn, %{"id" => transfer_id} = params) do
    user = conn.assigns.current_user
    expires_in = parse_int(params["expires_in"], 3600)
    with {:ok, transfer} <- get_user_transfer(user.id, transfer_id) do
      key = transfer.storage_path || Storage.generate_key(user.id, transfer.id, transfer.file_name)
      if is_nil(transfer.storage_path), do: Transfers.update_transfer(transfer, %{storage_path: key})
      {:ok, url} = Storage.presigned_upload_url(key, expires_in)
      json(conn, %{status: "success", data: %{url: url, key: key, expires_in: expires_in, method: "PUT"}})
    end
  end

  defp get_user_transfer(user_id, transfer_id) do
    case Transfers.get_user_transfer(user_id, transfer_id) do
      nil -> {:error, :not_found}
      transfer -> {:ok, transfer}
    end
  end

  defp get_upload_id(transfer) do
    case get_in(transfer.metadata || %{}, ["upload_id"]) do
      nil -> {:error, :no_upload_id}
      upload_id -> {:ok, upload_id}
    end
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      _ -> default
    end
  end
end
