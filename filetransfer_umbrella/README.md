# ZipShare

Lightning-fast file transfers with real-time progress tracking, resumable uploads, and end-to-end encryption.

## Project Structure

This is an Elixir umbrella project with the following apps:

- **filetransfer_core** - Business logic, Ecto schemas, and database access
- **filetransfer_web** - Phoenix web interface with LiveView
- **filetransfer_api** - REST API endpoints

## Getting Started

```bash
# Install dependencies and set up the database
mix setup

# Start the Phoenix server
mix phx.server

# Or start with interactive shell
iex -S mix phx.server
```

Visit [localhost:4000](http://localhost:4000) from your browser.

## Features

- 🚀 Large file support (up to 10GB+)
- ⚡ Real-time progress tracking
- 🔄 Resumable uploads
- 🔒 End-to-end 256-bit AES encryption
- 🔗 Secure file sharing with expiring links
- 👥 User management and role-based access

## Development

```bash
# Run all tests
mix test

# Run pre-commit checks (required before committing)
mix precommit

# Database operations
mix ecto.migrate     # Run migrations
mix ecto.rollback    # Rollback last migration
mix ecto.reset       # Drop, create, migrate, seed
```

## License

Copyright © 2024 ZipShare. All rights reserved.
