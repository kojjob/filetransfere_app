defmodule FiletransferWeb.Plugs.RequireProjectOwner do
  @moduledoc """
  Plug to ensure the authenticated user has the project_owner role.

  This plug should be used AFTER RequireAuth to verify the user is both
  authenticated AND has project owner privileges.

  Returns 403 Forbidden if user is authenticated but not a project owner.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2, redirect: 2, put_flash: 3]

  alias FiletransferCore.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        # Not authenticated - should have been caught by RequireAuth
        # But handle defensively
        handle_unauthorized(conn, "Authentication required")

      user ->
        if Accounts.project_owner?(user) do
          conn
        else
          handle_forbidden(conn)
        end
    end
  end

  defp handle_unauthorized(conn, message) do
    if api_request?(conn) do
      conn
      |> put_status(:unauthorized)
      |> json(%{status: "error", message: message})
      |> halt()
    else
      conn
      |> put_flash(:error, message)
      |> redirect(to: "/")
      |> halt()
    end
  end

  defp handle_forbidden(conn) do
    if api_request?(conn) do
      conn
      |> put_status(:forbidden)
      |> json(%{
        status: "error",
        message: "Access denied. Project owner privileges required."
      })
      |> halt()
    else
      conn
      |> put_flash(:error, "Access denied. You don't have permission to access this area.")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end

  defp api_request?(conn) do
    # Check if request accepts JSON or is under /api path
    case get_req_header(conn, "accept") do
      [accept] when is_binary(accept) ->
        String.contains?(accept, "application/json")

      _ ->
        String.starts_with?(conn.request_path, "/api")
    end
  end
end
