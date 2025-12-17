# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ZipShare is a file transfer application built as an Elixir umbrella project with a separate static landing page for market validation.

## Build & Development Commands

All commands run from `filetransfer_umbrella/` directory:

```bash
# Initial setup
mix setup                    # Install deps, create DB, run migrations

# Development
mix phx.server               # Start Phoenix server (localhost:4000)
iex -S mix phx.server        # Start with interactive shell

# Testing
mix test                     # Run all tests
mix test apps/filetransfer_core/test/  # Test specific app
mix test test/path/file_test.exs:42    # Run single test at line

# Pre-commit (REQUIRED before committing)
mix precommit                # Compiles (warnings as errors), unlocks unused deps, formats, runs tests

# Database
mix ecto.migrate             # Run migrations
mix ecto.rollback            # Rollback last migration
mix ecto.reset               # Drop, create, migrate, seed

# Assets
mix assets.build             # Build CSS/JS assets
mix assets.deploy            # Minify assets for production
```

## Architecture

### Umbrella Structure

```
filetransfer_umbrella/
├── apps/
│   ├── filetransfer_core/   # Business logic, Ecto schemas, database access
│   ├── filetransfer_web/    # Phoenix web interface (LiveView, controllers)
│   └── filetransfer_api/    # REST API endpoints (separate from web)
└── config/                  # Shared configuration
```

**Dependency flow**: `filetransfer_web` and `filetransfer_api` depend on `filetransfer_core`. Core has no knowledge of web/api layers.

### Core App Domains (`filetransfer_core`)

- `Accounts` - User authentication (bcrypt)
- `Transfers` - File transfer records
- `Chunks` - File chunking for large transfers
- `Sharing` - Share links for file access
- `Waitlist` - Pre-launch waitlist entries
- `Usage` - Usage statistics tracking
- `Api` - API key management

### Web App Structure (`filetransfer_web`)

- Phoenix 1.8 with LiveView 1.1
- Tailwind CSS v4 (no config file, uses `@import "tailwindcss"` in app.css)
- Bandit HTTP server
- Controllers: `AuthController`, `WaitlistController`, `PageController`
- Plugs: `RequireAuth`, `CORS`

### API Routes

```
POST /api/auth/register     # User registration
POST /api/auth/login        # User login
POST /api/auth/logout       # User logout
GET  /api/auth/me           # Current user
POST /api/waitlist          # Join waitlist (public)
```

## Key Conventions

### Phoenix 1.8 Specifics

- LiveView templates must start with `<Layouts.app flash={@flash} ...>`
- Use `<.icon name="hero-x-mark">` for icons (Heroicons)
- Use `<.input>` component from `core_components.ex` for forms
- `<.flash_group>` only in `layouts.ex`
- No inline `<script>` tags—all JS goes in `assets/js/`

### Elixir Patterns

- Use `Req` library for HTTP requests (not HTTPoison/Tesla)
- Lists don't support index access (`list[i]`)—use `Enum.at/2`
- Don't use map access syntax on structs (`changeset[:field]`)
- Block expressions must bind results: `socket = if connected?(socket), do: ...`
- No nested module definitions in same file

### LiveView Guidelines

- Use streams for collections (not plain assigns): `stream(socket, :items, items)`
- Streams require `phx-update="stream"` on parent element
- To filter/reset streams: refetch data and pass `reset: true`
- Use `<.form for={@form}>` with `to_form/2`, never pass changesets directly
- No `live_redirect`/`live_patch`—use `<.link navigate={}>` or `push_navigate`

### Testing

- Use `Phoenix.LiveViewTest` and `LazyHTML` for assertions
- Test element presence with `has_element?/2`, not raw HTML matching
- Debug selectors with: `html |> LazyHTML.from_fragment() |> LazyHTML.filter("selector") |> IO.inspect()`

## Landing Page

Static HTML landing page at `landing/index.html` for market validation. Currently uses localStorage for waitlist—connects to `/api/waitlist` endpoint in production.
