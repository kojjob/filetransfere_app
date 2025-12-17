defmodule FiletransferWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid Plug.Conn responses.
  """
  use FiletransferWeb, :controller

  def call(conn, {:error, :not_found}), do: conn |> put_status(:not_found) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "Resource not found")
  def call(conn, {:error, :unauthorized}), do: conn |> put_status(:unauthorized) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "Unauthorized")
  def call(conn, {:error, :forbidden}), do: conn |> put_status(:forbidden) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "Forbidden")
  def call(conn, {:error, :no_upload_id}), do: conn |> put_status(:bad_request) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "No multipart upload in progress")
  def call(conn, {:error, :transfer_not_complete}), do: conn |> put_status(:bad_request) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "Transfer is not complete")
  def call(conn, {:error, :no_storage_path}), do: conn |> put_status(:bad_request) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "File has not been uploaded")
  def call(conn, {:error, :transfer_not_ready}), do: conn |> put_status(:bad_request) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "Transfer is not ready")
  def call(conn, {:error, :upload_init_failed}), do: conn |> put_status(:internal_server_error) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "Failed to initialize upload")
  def call(conn, {:error, :chunk_upload_failed}), do: conn |> put_status(:internal_server_error) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "Failed to upload chunk")
  def call(conn, {:error, :upload_complete_failed}), do: conn |> put_status(:internal_server_error) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "Failed to complete upload")
  def call(conn, {:error, :download_failed}), do: conn |> put_status(:internal_server_error) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: "Failed to download file")
  def call(conn, {:error, %Ecto.Changeset{} = changeset}), do: conn |> put_status(:unprocessable_entity) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:changeset_error, changeset: changeset)
  def call(conn, {:error, reason}) when is_atom(reason), do: conn |> put_status(:bad_request) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: humanize_error(reason))
  def call(conn, {:error, message}) when is_binary(message), do: conn |> put_status(:bad_request) |> put_view(json: FiletransferWeb.ErrorJSON) |> render(:error, message: message)

  defp humanize_error(atom), do: atom |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
end
