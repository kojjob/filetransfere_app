defmodule FiletransferWeb.AuthController do
  use FiletransferWeb, :controller
  alias FiletransferCore.Accounts

  def register(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> put_session(:user_id, user.id)
        |> json(%{
          status: "success",
          user: %{
            id: user.id,
            email: user.email,
            name: user.name,
            subscription_tier: user.subscription_tier
          }
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

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> json(%{
          status: "success",
          user: %{
            id: user.id,
            email: user.email,
            name: user.name,
            subscription_tier: user.subscription_tier
          }
        })

      {:error, :invalid_password} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", message: "Invalid email or password"})

      {:error, :not_found} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", message: "Invalid email or password"})
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> json(%{status: "success", message: "Logged out"})
  end

  def current_user(conn, _params) do
    case get_session(conn, :user_id) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", message: "Not authenticated"})

      user_id ->
        user = Accounts.get_user!(user_id)

        json(conn, %{
          status: "success",
          user: %{
            id: user.id,
            email: user.email,
            name: user.name,
            subscription_tier: user.subscription_tier
          }
        })
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


