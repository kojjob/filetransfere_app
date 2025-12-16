# Security Implementation Guide

Quick implementation guide for critical security features.

---

## 1. Secure CORS Configuration

**File**: `filetransfer_umbrella/apps/filetransfer_web/lib/filetransfer_web/plugs/cors.ex`

```elixir
defmodule FiletransferWeb.Plugs.CORS do
  @moduledoc """
  CORS plug for allowing cross-origin requests from the landing page.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    allowed_origins = get_allowed_origins()
    
    conn
    |> put_resp_header("access-control-allow-origin", allowed_origins)
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization")
    |> put_resp_header("access-control-max-age", "86400")
    |> put_resp_header("access-control-allow-credentials", "true")
  end

  defp get_allowed_origins do
    case System.get_env("ALLOWED_ORIGINS") do
      nil -> 
        # Default to localhost for development
        if Mix.env() == :dev, do: "*", else: raise("ALLOWED_ORIGINS must be set in production")
      origins -> 
        # Support multiple origins separated by commas
        origins
    end
  end
end
```

**Environment Variable**:
```bash
# Production
ALLOWED_ORIGINS=https://flowtransfer.com,https://www.flowtransfer.com
```

---

## 2. Rate Limiting with PlugAttack

**Add to `mix.exs`**:
```elixir
{:plug_attack, "~> 0.4.0"}
```

**Create**: `filetransfer_umbrella/apps/filetransfer_web/lib/filetransfer_web/plugs/rate_limit.ex`

```elixir
defmodule FiletransferWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug for waitlist endpoint.
  """
  use PlugAttack

  rule "allow max 5 requests per hour", conn do
    import Plug.Conn, only: [get_req_header: 2]
    
    remote_ip = 
      conn.remote_ip
      |> Tuple.to_list()
      |> Enum.join(".")
    
    limit(remote_ip, period: 60 * 60, limit: 5)
  end

  def block_action(conn, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(429, Jason.encode!(%{
      status: "error",
      message: "Too many requests. Please try again later."
    }))
    |> halt()
  end
end
```

**Add to router**:
```elixir
scope "/api", FiletransferWeb do
  pipe_through [:api, FiletransferWeb.Plugs.RateLimit]

  options "/waitlist", WaitlistController, :options
  post "/waitlist", WaitlistController, :create
end
```

---

## 3. Security Headers

**Create**: `filetransfer_umbrella/apps/filetransfer_web/lib/filetransfer_web/plugs/security_headers.ex`

```elixir
defmodule FiletransferWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Security headers plug for production.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("content-security-policy", get_csp())
  end

  defp get_csp do
    # Adjust based on your needs
    "default-src 'self'; script-src 'self' 'unsafe-inline' https://www.googletagmanager.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://api.flowtransfer.com;"
  end
end
```

**Add to endpoint**:
```elixir
# In filetransfer_umbrella/apps/filetransfer_web/lib/filetransfer_web/endpoint.ex
plug FiletransferWeb.Plugs.SecurityHeaders
```

---

## 4. CAPTCHA Integration (reCAPTCHA v3)

**Add to landing page** (`landing/index.html`):

```html
<!-- Add before closing </head> -->
<script src="https://www.google.com/recaptcha/api.js?render=YOUR_SITE_KEY"></script>

<script>
  // In form submission handler
  grecaptcha.ready(function() {
    grecaptcha.execute('YOUR_SITE_KEY', {action: 'waitlist_submit'}).then(function(token) {
      formData.waitlist_entry.recaptcha_token = token;
      // Continue with fetch...
    });
  });
</script>
```

**Verify on backend** (`WaitlistController`):

```elixir
def create(conn, %{"waitlist_entry" => waitlist_params}) do
  # Verify reCAPTCHA
  case verify_recaptcha(waitlist_params["recaptcha_token"]) do
    {:ok, true} ->
      # Continue with existing logic
      # ...
    {:error, _reason} ->
      conn
      |> put_status(:bad_request)
      |> json(%{status: "error", message: "CAPTCHA verification failed"})
  end
end

defp verify_recaptcha(token) do
  secret_key = System.get_env("RECAPTCHA_SECRET_KEY")
  url = "https://www.google.com/recaptcha/api/siteverify"
  
  body = URI.encode_query(%{
    secret: secret_key,
    response: token
  })
  
  case Req.post(url, body: body) do
    {:ok, %{status: 200, body: %{"success" => true}}} -> {:ok, true}
    _ -> {:error, :verification_failed}
  end
end
```

---

## 5. Environment-Aware API URL

**Update landing page** (`landing/index.html`):

```javascript
// Replace hardcoded localhost URL
const getApiUrl = () => {
  // Check if we're in production
  if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
    // Production: use same origin or configured API domain
    return window.location.origin.includes('flowtransfer.com') 
      ? 'https://api.flowtransfer.com/api/waitlist'
      : `${window.location.origin}/api/waitlist`;
  }
  // Development
  return 'http://localhost:4000/api/waitlist';
};

// In form submission
const apiUrl = getApiUrl();
```

---

## 6. Production Configuration

**Update `config/runtime.exs`**:

```elixir
if config_env() == :prod do
  # Database
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      Example: postgres://user:password@host:5432/database
      """

  config :filetransfer_core, FiletransferCore.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # Endpoint
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing."

  host = System.get_env("PHX_HOST") || raise "PHX_HOST environment variable is missing"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :filetransfer_web, FiletransferWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true

  # CORS
  config :filetransfer_web, :allowed_origins,
    System.get_env("ALLOWED_ORIGINS") || raise "ALLOWED_ORIGINS must be set"
end
```

---

## 7. Required Environment Variables

Create `.env.production` (DO NOT COMMIT):

```bash
# Database
DATABASE_URL=postgres://user:password@host:5432/filetransfer_prod

# Phoenix
SECRET_KEY_BASE=your_secret_key_here
PHX_HOST=api.flowtransfer.com
PORT=4000

# CORS
ALLOWED_ORIGINS=https://flowtransfer.com,https://www.flowtransfer.com

# reCAPTCHA (if using)
RECAPTCHA_SECRET_KEY=your_secret_key_here

# Email (if sending confirmation emails)
SMTP_HOST=smtp.example.com
SMTP_USER=your_email@example.com
SMTP_PASSWORD=your_password
```

---

## 8. Testing Security

**Test CORS**:
```bash
# Should work
curl -H "Origin: https://flowtransfer.com" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS https://api.flowtransfer.com/api/waitlist

# Should fail
curl -H "Origin: https://evil.com" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS https://api.flowtransfer.com/api/waitlist
```

**Test Rate Limiting**:
```bash
# Make 6 requests quickly - 6th should fail
for i in {1..6}; do
  curl -X POST https://api.flowtransfer.com/api/waitlist \
    -H "Content-Type: application/json" \
    -d '{"waitlist_entry":{"email":"test'$i'@example.com"}}'
  echo ""
done
```

---

## Priority Order

1. ✅ **CORS** - Fix immediately (security risk)
2. ✅ **Rate Limiting** - Prevent abuse
3. ✅ **Security Headers** - Basic protection
4. ✅ **API URL** - Required for functionality
5. ✅ **CAPTCHA** - Add after basic deployment works
6. ✅ **Environment Variables** - Required for production

---

## Next Steps

1. Implement CORS fix
2. Add rate limiting
3. Update API URL in landing page
4. Test locally with production-like config
5. Deploy to staging environment
6. Run security tests
7. Deploy to production

