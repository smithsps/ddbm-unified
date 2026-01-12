# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
# Initial setup (from umbrella root)
mix setup

# Run development server
mix phx.server

# Run tests
mix test                           # all tests
mix test test/my_test.exs          # specific file
mix test --failed                  # re-run failed tests

# Pre-commit check (compile warnings, format, tests)
mix precommit

# Database operations
mix ecto.migrate
mix ecto.reset                     # drop, create, migrate, seed

# Assets
mix assets.build                   # build CSS/JS
mix assets.deploy                  # minified production build
```

## Architecture

This is a Phoenix 1.8 umbrella application with three child apps:

- **`ddbm`** - Core business logic and Ecto schemas. Uses SQLite (`ecto_sqlite3`). Contains `Ddbm.Repo`.
- **`ddbm_web`** - Phoenix web interface with LiveView. Depends on `ddbm` for data access. Uses Bandit as the HTTP server.
- **`ddbm_discord`** - Discord bot using Nostrum. Depends on `ddbm` for data access. Bot token loaded via `dotenvy`.

Context modules and schemas go in `ddbm`, web-specific code (LiveViews, controllers, components) in `ddbm_web`.

## Key Conventions

### Phoenix 1.8 / LiveView

- LiveView templates must begin with `<Layouts.app flash={@flash} ...>` wrapper
- Use `<.icon name="hero-x-mark" />` for icons (heroicons)
- Use `<.input field={@form[:field]} />` for form inputs
- Forms must use `to_form/2` assigned in LiveView, never pass changesets directly to templates
- Use LiveView streams for collections (not regular assigns) to prevent memory issues
- Router scopes auto-alias modules - don't add redundant aliases

### Elixir

- Use `Req` for HTTP requests (already included), avoid HTTPoison/Tesla/httpc
- Lists don't support index access (`list[0]`), use `Enum.at/2`
- Use `Ecto.Changeset.get_field/2` to access changeset fields, not `changeset[:field]`
- Block expressions must bind results: `socket = if connected?(socket), do: assign(...)`

### Tailwind CSS v4

- No `tailwind.config.js` needed - uses `@import "tailwindcss"` syntax in `app.css`
- Never use `@apply`
- All vendor JS/CSS must be imported into app.js/app.css, no external script tags
