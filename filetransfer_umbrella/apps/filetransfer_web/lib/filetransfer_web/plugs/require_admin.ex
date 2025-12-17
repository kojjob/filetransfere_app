defmodule FiletransferWeb.Plugs.RequireAdmin do
  @moduledoc """
  Plug to protect admin routes with Basic Authentication and rate limiting.

  Set ADMIN_USERNAME and ADMIN_PASSWORD environment variables in production.
  Defaults: username must be set in production (no default), password must be set.

  Rate limiting: 5 failed attempts per IP blocks for 15 minutes.
  """
  import Plug.Conn

  @max_attempts 5
  # 15 minutes
  @lockout_seconds 900

  def init(opts), do: opts

  def call(conn, _opts) do
    admin_username = System.get_env("ADMIN_USERNAME")
    admin_password = System.get_env("ADMIN_PASSWORD")
    client_ip = get_client_ip(conn)

    cond do
      # Check if IP is rate limited
      rate_limited?(client_ip) ->
        conn
        |> send_resp(429, "Too many failed attempts. Try again later.")
        |> halt()

      # If no username/password is set and we're in production, block access
      is_nil(admin_username) or admin_username == "" or
        is_nil(admin_password) or admin_password == "" ->
        if Application.get_env(:filetransfer_web, :env) == :prod do
          conn
          |> send_resp(403, "Admin access disabled. Set ADMIN_USERNAME and ADMIN_PASSWORD.")
          |> halt()
        else
          # Allow access in dev/test without credentials
          conn
        end

      # Credentials are set, require Basic Auth
      true ->
        verify_basic_auth(conn, admin_username, admin_password, client_ip)
    end
  end

  defp verify_basic_auth(conn, expected_username, expected_password, client_ip) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded] ->
        case Base.decode64(encoded) do
          {:ok, credentials} ->
            case String.split(credentials, ":", parts: 2) do
              [username, password]
              when username == expected_username and password == expected_password ->
                # Success - clear any failed attempts
                clear_failed_attempts(client_ip)
                conn

              _ ->
                record_failed_attempt(client_ip)
                unauthorized(conn)
            end

          _ ->
            record_failed_attempt(client_ip)
            unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", ~s(Basic realm="ZipShare Admin"))
    |> send_resp(401, "Unauthorized")
    |> halt()
  end

  # Rate limiting using process dictionary (simple in-memory for single instance)
  # For multi-instance, use ETS or Redis
  defp get_client_ip(conn) do
    # Check for forwarded IP (behind proxy/load balancer)
    forwarded = get_req_header(conn, "x-forwarded-for")

    case forwarded do
      [ip | _] -> ip |> String.split(",") |> List.first() |> String.trim()
      _ -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  defp rate_limited?(ip) do
    case :persistent_term.get({:admin_lockout, ip}, nil) do
      nil -> false
      lockout_until -> System.system_time(:second) < lockout_until
    end
  end

  defp record_failed_attempt(ip) do
    key = {:admin_attempts, ip}
    attempts = :persistent_term.get(key, 0) + 1
    :persistent_term.put(key, attempts)

    if attempts >= @max_attempts do
      lockout_until = System.system_time(:second) + @lockout_seconds
      :persistent_term.put({:admin_lockout, ip}, lockout_until)
    end
  end

  defp clear_failed_attempts(ip) do
    :persistent_term.erase({:admin_attempts, ip})
    :persistent_term.erase({:admin_lockout, ip})
  catch
    # persistent_term.erase can raise if key doesn't exist in older OTP versions
    _, _ -> :ok
  end
end
