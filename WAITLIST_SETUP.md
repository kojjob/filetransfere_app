# Waitlist Email Collection Setup Guide

This guide explains how to collect and persist waitlist emails from your landing page.

## What's Been Set Up

### 1. Database Schema
- **Migration**: `20241216000007_create_waitlist_entries.exs`
- **Table**: `waitlist_entries`
- **Fields**:
  - `email` (required, unique)
  - `name` (optional)
  - `use_case` (optional)
  - `source` (default: "landing_page")
  - `ip_address` (captured automatically)
  - `user_agent` (captured automatically)
  - `notified_at` (when you send launch email)
  - `converted_at` (when they sign up as a user)

### 2. Backend Components
- **Schema**: `FiletransferCore.Waitlist.WaitlistEntry`
- **Context**: `FiletransferCore.Waitlist` (handles all waitlist operations)
- **Controller**: `FiletransferWeb.WaitlistController`
- **Route**: `POST /api/waitlist`

### 3. Frontend Integration
- Landing page form now sends data to backend API
- CORS enabled for cross-origin requests
- Error handling and loading states

## Setup Instructions

### Step 1: Install Dependencies

```bash
cd filetransfer_umbrella
mix deps.get
```

### Step 2: Set Up Database

Make sure PostgreSQL is running, then:

```bash
cd apps/filetransfer_core
mix ecto.create
mix ecto.migrate
```

### Step 3: Start the Phoenix Server

```bash
cd filetransfer_umbrella
mix phx.server
```

The API will be available at `http://localhost:4000/api/waitlist`

### Step 4: Update Landing Page API URL (if needed)

If your landing page is served from a different domain/port, update the API URL in `landing/index.html`:

```javascript
// Line ~830 in landing/index.html
const apiUrl = 'http://localhost:4000/api/waitlist';
```

For production, change this to your actual API domain:
```javascript
const apiUrl = 'https://api.yourdomain.com/api/waitlist';
```

## Testing

### Test the API Endpoint

```bash
curl -X POST http://localhost:4000/api/waitlist \
  -H "Content-Type: application/json" \
  -d '{
    "waitlist_entry": {
      "email": "test@example.com",
      "name": "Test User",
      "use_case": "Video editing"
    }
  }'
```

Expected response:
```json
{
  "status": "success",
  "message": "Successfully added to waitlist!",
  "data": {
    "id": "...",
    "email": "test@example.com"
  }
}
```

### Test from Landing Page

1. Open `landing/index.html` in a browser
2. Fill out the waitlist form
3. Submit and check the browser console for any errors
4. Verify the entry was saved in the database:

```bash
# In IEx console
iex -S mix phx.server

# Then in the console:
alias FiletransferCore.Waitlist
Waitlist.list_waitlist_entries()
```

## Querying Waitlist Entries

### In IEx Console

```elixir
# List all entries
FiletransferCore.Waitlist.list_waitlist_entries()

# Get entry by email
FiletransferCore.Waitlist.get_waitlist_entry_by_email("user@example.com")

# Count entries
FiletransferCore.Waitlist.count_waitlist_entries()
```

### Export to CSV (Example)

You can create a simple script to export waitlist entries:

```elixir
# In IEx
entries = FiletransferCore.Waitlist.list_waitlist_entries()

CSV.encode([
  ["Email", "Name", "Use Case", "Created At"]
] ++ Enum.map(entries, fn e ->
  [e.email, e.name || "", e.use_case || "", e.inserted_at]
end))
|> Enum.join()
|> IO.puts()
```

## Next Steps

1. **Email Notifications**: Set up email sending when entries are created
2. **Admin Dashboard**: Create an admin interface to view/manage waitlist entries
3. **Analytics**: Track conversion rates (waitlist → signup)
4. **Export**: Add functionality to export waitlist to CSV/Excel
5. **Duplicate Prevention**: Already handled by unique constraint on email

## Production Considerations

1. **Rate Limiting**: Add rate limiting to prevent spam
2. **Email Validation**: Consider adding email verification
3. **CAPTCHA**: Add CAPTCHA to prevent bots
4. **CORS**: Restrict CORS to your actual landing page domain
5. **HTTPS**: Always use HTTPS in production
6. **Database Backups**: Set up regular backups

## CORS Configuration

Currently, CORS is set to allow all origins (`*`). For production, update `FiletransferWeb.Plugs.CORS`:

```elixir
def call(conn, _opts) do
  allowed_origins = System.get_env("ALLOWED_ORIGINS", "*")
  
  conn
  |> put_resp_header("access-control-allow-origin", allowed_origins)
  # ... rest of headers
end
```

Then set `ALLOWED_ORIGINS` environment variable to your landing page domain.

## Troubleshooting

### Issue: CORS errors in browser
- **Solution**: Make sure CORS plug is in the API pipeline
- Check browser console for specific error messages

### Issue: Database connection errors
- **Solution**: Verify PostgreSQL is running
- Check database credentials in `config/dev.exs`

### Issue: Form submission fails silently
- **Solution**: Check browser console for errors
- Verify API endpoint is accessible
- Check network tab in browser dev tools

### Issue: Duplicate email errors
- **Solution**: This is expected - emails must be unique
- Show user-friendly message: "This email is already on the waitlist"
