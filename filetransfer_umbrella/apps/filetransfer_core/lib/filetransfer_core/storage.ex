defmodule FiletransferCore.Storage do
  @moduledoc """
  Storage context for managing file uploads to S3-compatible storage.

  Handles chunked uploads, multipart uploads, and presigned URLs
  for secure file access.
  """

  alias ExAws.S3
  require Logger

  @doc """
  Returns the configured S3 bucket name.
  """
  def bucket do
    Application.get_env(:filetransfer_core, __MODULE__)[:bucket] || "filetransfer-dev"
  end

  @doc """
  Returns the configured chunk size in bytes.
  """
  def chunk_size do
    Application.get_env(:filetransfer_core, __MODULE__)[:chunk_size] || 5_242_880
  end

  @doc """
  Returns the maximum file size in bytes.
  """
  def max_file_size do
    Application.get_env(:filetransfer_core, __MODULE__)[:max_file_size] || 10_737_418_240
  end

  @doc """
  Generates the S3 key (path) for a transfer file.
  """
  def generate_key(user_id, transfer_id, file_name) do
    "uploads/#{user_id}/#{transfer_id}/#{sanitize_filename(file_name)}"
  end

  @doc """
  Initiates a multipart upload for large files.
  """
  def initiate_multipart_upload(key, content_type \\ "application/octet-stream") do
    bucket()
    |> S3.initiate_multipart_upload(key, content_type: content_type)
    |> ExAws.request()
    |> case do
      {:ok, %{body: %{upload_id: upload_id}}} -> {:ok, upload_id}
      {:error, error} ->
        Logger.error("Failed to initiate multipart upload: #{inspect(error)}")
        {:error, :upload_init_failed}
    end
  end

  @doc """
  Uploads a single chunk as part of a multipart upload.
  """
  def upload_chunk(key, upload_id, part_number, chunk_data) do
    bucket()
    |> S3.upload_part(key, upload_id, part_number, chunk_data)
    |> ExAws.request()
    |> case do
      {:ok, %{headers: headers}} ->
        etag = get_header(headers, "etag") |> String.trim("\"")
        {:ok, etag}
      {:error, error} ->
        Logger.error("Failed to upload chunk #{part_number}: #{inspect(error)}")
        {:error, :chunk_upload_failed}
    end
  end

  @doc """
  Completes a multipart upload.
  """
  def complete_multipart_upload(key, upload_id, parts) do
    bucket()
    |> S3.complete_multipart_upload(key, upload_id, parts)
    |> ExAws.request()
    |> case do
      {:ok, _} -> {:ok, key}
      {:error, error} ->
        Logger.error("Failed to complete multipart upload: #{inspect(error)}")
        {:error, :upload_complete_failed}
    end
  end

  @doc """
  Aborts a multipart upload.
  """
  def abort_multipart_upload(key, upload_id) do
    bucket()
    |> S3.abort_multipart_upload(key, upload_id)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  @doc """
  Generates a presigned URL for downloading.
  """
  def presigned_download_url(key, expires_in \\ 3600) do
    config = ExAws.Config.new(:s3)
    bucket() |> S3.presigned_url(config, :get, key, expires_in: expires_in)
  end

  @doc """
  Generates a presigned URL for uploading.
  """
  def presigned_upload_url(key, expires_in \\ 3600) do
    config = ExAws.Config.new(:s3)
    bucket() |> S3.presigned_url(config, :put, key, expires_in: expires_in)
  end

  @doc """
  Downloads a file from S3.
  """
  def download_file(key) do
    bucket()
    |> S3.get_object(key)
    |> ExAws.request()
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, {:http_error, 404, _}} -> {:error, :not_found}
      {:error, error} ->
        Logger.error("Failed to download file: #{inspect(error)}")
        {:error, :download_failed}
    end
  end

  @doc """
  Deletes a file from S3.
  """
  def delete_file(key) do
    bucket()
    |> S3.delete_object(key)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/[^\w\s\-\.]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.downcase()
  end

  defp get_header(headers, key) do
    Enum.find_value(headers, "", fn {k, v} ->
      if String.downcase(k) == key, do: v
    end)
  end
end
