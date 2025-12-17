defmodule FiletransferWeb.DownloadController do
  @moduledoc """
  Controller for handling file download operations.
  """
  use FiletransferWeb, :controller

  alias FiletransferCore.{Transfers, Storage}

  action_fallback FiletransferWeb.FallbackController

  def download(conn, %{"id" => transfer_id}) do
    user = conn.assigns.current_user
    with {:ok, transfer} <- get_user_transfer(user.id, transfer_id),
         :ok <- validate_download(transfer),
         {:ok, body} <- Storage.download_file(transfer.storage_path) do
      conn
      |> put_resp_content_type(transfer.file_type || "application/octet-stream")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{transfer.file_name}\"")
      |> send_resp(200, body)
    end
  end

  def presigned_url(conn, %{"id" => transfer_id} = params) do
    user = conn.assigns.current_user
    expires_in = parse_int(params["expires_in"], 3600)
    with {:ok, transfer} <- get_user_transfer(user.id, transfer_id),
         :ok <- validate_download(transfer),
         {:ok, url} <- Storage.presigned_download_url(transfer.storage_path, expires_in) do
      json(conn, %{
        status: "success",
        data: %{
          url: url,
          file_name: transfer.file_name,
          file_size: transfer.file_size,
          content_type: transfer.file_type,
          expires_in: expires_in
        }
      })
    end
  end

  defp get_user_transfer(user_id, transfer_id) do
    case Transfers.get_user_transfer(user_id, transfer_id) do
      nil -> {:error, :not_found}
      transfer -> {:ok, transfer}
    end
  end

  defp validate_download(transfer) do
    cond do
      transfer.status != "completed" -> {:error, :transfer_not_complete}
      is_nil(transfer.storage_path) -> {:error, :no_storage_path}
      true -> :ok
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
