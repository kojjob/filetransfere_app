defmodule FiletransferWeb.WaitlistController do
  use FiletransferWeb, :controller
  alias FiletransferCore.Waitlist
  alias FiletransferWeb.Notifiers.WaitlistNotifier

  require Logger

  def options(conn, _params) do
    conn
    |> send_resp(:no_content, "")
  end

  def create(conn, %{"waitlist_entry" => waitlist_params}) do
    # Extract IP address and user agent
    ip_address = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    user_agent = get_req_header(conn, "user-agent") |> List.first()

    attrs =
      waitlist_params
      |> Map.put("ip_address", ip_address)
      |> Map.put("user_agent", user_agent)

    case Waitlist.create_waitlist_entry(attrs) do
      {:ok, waitlist_entry} ->
        # Send welcome email asynchronously
        Task.start(fn ->
          case WaitlistNotifier.deliver_welcome_email(waitlist_entry) do
            {:ok, _metadata} ->
              Logger.info("Welcome email sent to #{waitlist_entry.email}")

            {:error, reason} ->
              Logger.error(
                "Failed to send welcome email to #{waitlist_entry.email}: #{inspect(reason)}"
              )
          end
        end)

        conn
        |> put_status(:created)
        |> json(%{
          status: "success",
          message: "Successfully added to waitlist!",
          data: %{
            id: waitlist_entry.id,
            email: waitlist_entry.email
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          status: "error",
          message: "Failed to add to waitlist",
          errors: translate_errors(changeset)
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
