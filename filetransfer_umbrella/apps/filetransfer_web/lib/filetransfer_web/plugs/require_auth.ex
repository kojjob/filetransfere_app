defmodule FiletransferWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  alias FiletransferCore.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", message: "Authentication required"})
        |> halt()

      user_id ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> clear_session()
            |> put_status(:unauthorized)
            |> json(%{status: "error", message: "Invalid session"})
            |> halt()

          user ->
            assign(conn, :current_user, user)
        end
    end
  end
end
