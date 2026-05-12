# Supabase setup

Schema lives in `migrations/`. Apply it either via the Supabase CLI or by pasting each file into the SQL editor in the dashboard.

## Option A — Supabase CLI (recommended for ongoing dev)

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

`supabase db push` applies every migration in `migrations/` in filename order.

For local dev against a Dockerized Supabase:

```bash
supabase start    # spins up local Postgres + auth + studio at localhost:54321
supabase db reset # applies migrations to the local DB
```

## Option B — Dashboard SQL editor

Run the files in order:

1. `20260512000000_init.sql` — extensions, tables, indexes, profile trigger
2. `20260512000001_rls.sql` — Row Level Security policies
3. `20260512000002_bbox_query.sql` — bounding-box RPC for the shared map

## Auth providers

Configured in the Supabase dashboard, not in SQL.

**v1: Email only**

**Email** (Authentication → Providers → Email)
- Enabled by default — no extra setup
- For dev, disable "Confirm email" so signups go through without an SMTP round-trip

**Deferred providers** (not enabled in v1):

**Google** — re-enable when you want OAuth. Requires creating an OAuth 2.0 Client ID in Google Cloud Console (iOS application type, bundle ID matches the iOS app), then pasting the Client ID into Supabase → Authentication → Providers → Google.

**Apple** — requires an Apple Developer account ($99/yr). When ready: create a Services ID in the Apple Developer portal, enable Sign In with Apple, configure the redirect URL Supabase shows in the provider panel, paste the Client ID + Secret Key into Supabase → Authentication → Providers → Apple.

## Schema overview

- `profiles` — one row per signed-up user; auto-created by trigger on signup
- `hikes` — one row per completed hike; trail is a PostGIS LINESTRING; published by default
- `waypoints` — markers dropped during a hike; private by default, owner toggles `is_public`

RLS enforces: anyone can read published hikes and public waypoints; only the owner can read their private waypoints or modify their own data.
