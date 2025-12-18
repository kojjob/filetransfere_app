defmodule FiletransferWeb.ShareController do
  @moduledoc """
  Controller for managing share links.
  """
  use FiletransferWeb, :controller

  alias FiletransferCore.{Transfers, Sharing, Storage}

  action_fallback FiletransferWeb.FallbackController

  def create(conn, %{"id" => transfer_id} = params) do
    user = conn.assigns.current_user

    with {:ok, transfer} <- get_user_transfer(user.id, transfer_id),
         :ok <- validate_transfer_for_sharing(transfer),
         opts <- build_share_opts(params),
         {:ok, share_link} <- Sharing.create_share_link(transfer, user, opts) do
      conn
      |> put_status(:created)
      |> json(%{status: "success", data: serialize_share_link(share_link)})
    end
  end

  def index(conn, _params) do
    user = conn.assigns.current_user
    share_links = Sharing.list_user_share_links(user.id)
    json(conn, %{status: "success", data: Enum.map(share_links, &serialize_share_link/1)})
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, share_link} <- get_user_share_link(user.id, id) do
      json(conn, %{status: "success", data: serialize_share_link(share_link)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with {:ok, share_link} <- get_user_share_link(user.id, id),
         {:ok, updated} <- Sharing.update_share_link(share_link, build_update_attrs(params)) do
      json(conn, %{status: "success", data: serialize_share_link(updated)})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, share_link} <- get_user_share_link(user.id, id),
         {:ok, _} <- Sharing.delete_share_link(share_link) do
      json(conn, %{status: "success", message: "Share link deleted"})
    end
  end

  def access(conn, %{"token" => token}) do
    case Sharing.get_share_link_by_token(token) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Share link not found"})

      share_link ->
        if Sharing.password_required?(share_link) do
          json(conn, %{
            status: "password_required",
            data: %{
              file_name: share_link.transfer.file_name,
              file_size: share_link.transfer.file_size
            }
          })
        else
          case Sharing.validate_share_link(token) do
            {:ok, _} ->
              json(conn, %{status: "success", data: serialize_public_share(share_link)})

            {:error, reason} ->
              conn
              |> put_status(:forbidden)
              |> json(%{status: "error", message: share_error_message(reason)})
          end
        end
    end
  end

  def download(conn, %{"token" => token} = params) do
    case Sharing.validate_share_link(token, params["password"]) do
      {:ok, share_link} ->
        {:ok, _} = Sharing.record_download(share_link)
        {:ok, url} = Storage.presigned_download_url(share_link.transfer.storage_path, 300)

        json(conn, %{
          status: "success",
          data: %{
            download_url: url,
            file_name: share_link.transfer.file_name,
            file_size: share_link.transfer.file_size,
            expires_in: 300
          }
        })

      {:error, reason} ->
        status = if reason == :invalid_password, do: :unauthorized, else: :forbidden

        conn
        |> put_status(status)
        |> json(%{status: "error", message: share_error_message(reason)})
    end
  end

  defp get_user_transfer(user_id, transfer_id) do
    case Transfers.get_user_transfer(user_id, transfer_id) do
      nil -> {:error, :not_found}
      transfer -> {:ok, transfer}
    end
  end

  defp get_user_share_link(user_id, id) do
    try do
      share_link = Sharing.get_share_link!(id)
      if share_link.user_id == user_id, do: {:ok, share_link}, else: {:error, :not_found}
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
    end
  end

  defp validate_transfer_for_sharing(transfer) do
    if transfer.status == "completed" and not is_nil(transfer.storage_path) do
      :ok
    else
      {:error, :transfer_not_ready}
    end
  end

  defp build_share_opts(params) do
    opts = []
    opts = if params["password"], do: Keyword.put(opts, :password, params["password"]), else: opts

    opts =
      if params["expires_in"],
        do: Keyword.put(opts, :expires_in, parse_int(params["expires_in"])),
        else: opts

    opts =
      if params["max_downloads"],
        do: Keyword.put(opts, :max_downloads, parse_int(params["max_downloads"])),
        else: opts

    opts
  end

  defp build_update_attrs(params) do
    %{}
    |> maybe_put(:password, params["password"])
    |> maybe_put(:max_downloads, params["max_downloads"] && parse_int(params["max_downloads"]))
    |> maybe_put(:is_active, params["is_active"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp serialize_share_link(share_link) do
    %{
      id: share_link.id,
      token: share_link.token,
      url: Sharing.share_url(share_link),
      transfer_id: share_link.transfer_id,
      file_name: share_link.transfer && share_link.transfer.file_name,
      file_size: share_link.transfer && share_link.transfer.file_size,
      password_protected: Sharing.password_required?(share_link),
      expires_at: share_link.expires_at,
      max_downloads: share_link.max_downloads,
      download_count: share_link.download_count,
      is_active: share_link.is_active,
      created_at: share_link.inserted_at
    }
  end

  defp serialize_public_share(share_link) do
    %{
      file_name: share_link.transfer.file_name,
      file_size: share_link.transfer.file_size,
      file_type: share_link.transfer.file_type,
      download_count: share_link.download_count,
      max_downloads: share_link.max_downloads
    }
  end

  defp share_error_message(:not_found), do: "Share link not found"
  defp share_error_message(:link_disabled), do: "This share link has been disabled"
  defp share_error_message(:link_expired), do: "This share link has expired"
  defp share_error_message(:download_limit_exceeded), do: "Download limit exceeded"
  defp share_error_message(:invalid_password), do: "Invalid password"
  defp share_error_message(:transfer_not_ready), do: "Transfer is not ready for sharing"
  defp share_error_message(_), do: "Unable to access share link"

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
end
