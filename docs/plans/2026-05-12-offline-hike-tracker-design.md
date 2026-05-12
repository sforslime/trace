# Offline Hike Tracker — Design

**Date:** 2026-05-12
**Status:** Approved for implementation planning

## Summary

A native iOS + Android app for tracking hikes offline using GPS, layered over a shared community map. Users sign in, pre-download a map region, then record their hike (breadcrumb + steps + pace + distance) with no network. They drop waypoints along the way and pin a destination when they find one. When back online, the trail syncs publicly to a shared map; personal waypoints stay private unless explicitly shared. Saved trails can be followed in the future via a compass-driven guidance mode.

iOS ships first; Android follows once iOS is validated on TestFlight.

## Decisions

| Decision | Choice |
|---|---|
| Platform | Native iOS (Swift/SwiftUI) + Native Android (Kotlin/Compose) |
| Map rendering | MapLibre Native (open source, OpenStreetMap tiles) |
| Offline maps | Pre-downloaded regions; user picks before hiking |
| Backend | Supabase (Postgres + PostGIS, Auth, Storage) |
| Identity | Required accounts — Apple, Google, email |
| Group features | Solo tracking only in v1; no live hike |
| Visibility model | Trail public on shared map; waypoints private unless shared |
| Destination | Discovered & pinned during the hike (not pre-planned) |
| Hike duration | Optimize for 1–3 hour hikes |
| Tracking data | GPS breadcrumb, step count, distance, pace, elapsed time |
| Safety | Waypoints, back-to-start, off-trail alert, compass + coords |
| Future trail-following | Compass + bearing-to-next-point with off-trail drift alert |

## Architecture

Three pieces:

- **iOS app (Swift / SwiftUI)** — MapLibre Native iOS, CoreLocation for GPS, CoreMotion for steps, Core Data for local persistence, Keychain for auth tokens.
- **Android app (Kotlin / Jetpack Compose)** — MapLibre Native Android, FusedLocationProviderClient for GPS, SensorManager (TYPE_STEP_COUNTER) for steps, Room for local persistence, EncryptedSharedPreferences for tokens.
- **Backend (Supabase)** — Postgres + PostGIS, Supabase Auth (Apple/Google/email), Supabase Storage for future media on waypoints. Row Level Security enforces public-trail / private-waypoint split.

### Data flow at a glance

```
Hike start → app records GPS samples + steps locally (SQLite/Core Data)
           ↓
Hike end → user pins destination → trail saved as complete record locally
           ↓
Online   → SyncQueue uploads trail (public) + private waypoints (kept private)
           ↓
Shared map ← reads aggregated public trails + destinations from PostGIS
```

## Components (iOS, ported to Android)

**App shell** — Tab bar: Map / Hike / Library / Profile.

**Map module**
- `MapView` — MapLibre wrapper, renders shared map with trails + destination pins
- `OfflineRegionManager` — download/delete tile regions
- `TrailLayer` — renders public trails fetched from Supabase, cached locally

**Hike recording**
- `LocationTracker` — CoreLocation wrapper, background updates, adaptive sampling
- `StepTracker` — CMPedometer wrapper
- `HikeSession` — state machine (idle → recording → paused → finished), persists each sample
- `HikeStatsCalculator` — distance, pace, elapsed time from breadcrumb

**Destinations & waypoints**
- `WaypointStore` — drop pin at current GPS, optional note, private by default
- `DestinationPinner` — final waypoint marking endpoint; promotes trail to publishable

**Follow Trail mode**
- `TrailFollower` — bearing-to-next-point, nearest-point-on-LineString, drift distance
- `HeadingProvider` — CLHeading for compass
- `FollowMapView` — compass arrow + distance overlay

**Sync**
- `SyncQueue` — Core Data outbox, drains when network returns
- `SupabaseClient` — auth + PostgREST + RLS-aware reads/writes

**Safety**
- `BackToStartGuide` — TrailFollower applied to reversed breadcrumb of current hike
- `OffTrailMonitor` — fires when drift exceeds threshold in Follow mode

## Data Flow Details

**Recording a hike (offline default)**
- Start → Hike row created locally (status=recording)
- Each GPS sample appended to Core Data (crash-safe)
- Waypoints written locally as user drops them
- Destination pin marks hasDestination
- End → status=finished, hike enqueued for sync

**Syncing when online**
- POST /hikes → server stores trail geometry as LINESTRING in PostGIS
- POST /waypoints → only those flagged is_public=true
- Mark local hike as synced
- Failure → exponential backoff retry, hike stays in queue

**Browsing the shared map**
- Visible region changes → query trails + destinations in bounding box
- Response cached locally for offline re-view
- Tap a destination → "Follow this trail" downloads trail + surrounding tiles → Follow mode

**Auth**
- Sign in via Supabase Auth (Apple/Google/email) → JWT in Keychain
- RLS policies: anyone reads public trails; only owner reads/writes private waypoints

**Invariants**
- Local Core Data is source of truth during a hike
- Server is source of truth for the shared map
- A hike is never lost to network failure
- Private waypoints never appear in any server response unless explicitly published

## Error Handling

**GPS / location**
- No permission → block start, deep-link to Settings
- "While Using" → warn about screen-lock pause, offer upgrade to "Always"
- Signal lost → leave gap in breadcrumb, keep step count, show indicator
- Wild samples (accuracy >50m or >100m/s jumps) → discard

**Storage**
- Region download interrupted → resume on relaunch, don't fake completion
- Disk full → stop sampling, surface error, don't crash

**Sync**
- Auth expired → refresh; if fail, queue stays, prompt re-login
- Partial sync → idempotent retries keyed by client UUIDs
- Multi-device edits → last-write-wins on metadata, trail geometry immutable

**Follow Trail mode**
- Too far from trail start → don't silently follow; offer to guide to start
- Magnetometer interference (`headingAccuracy < 0`) → show calibration prompt
- Trail completed → log completion, offer to publish own variant

**Auth**
- Offline sign-in fail → guest-record mode for one hike, sync after sign-in

## Testing Strategy

**Unit (XCTest)**
- HikeStatsCalculator math on canned GPS fixtures
- TrailFollower geometry (bearing, nearest point, drift)
- SyncQueue retry/backoff/idempotency
- RLS policies via pgTAP on Supabase

**Integration**
- Record → persist → sync round-trip against local Supabase
- Offline → online transition drains queue
- Tile region download + retrieval

**Simulator**
- GPX playback via Features → Custom Location
- Permission-denied, low-disk, mid-hike force-quit flows

**Device (pre-release manual checklist)**
- 2-hour real walk: battery, background continuity, step accuracy
- Tree-cover walk: gap handling
- Follow Trail field test with a previously-recorded route
- TestFlight build through Apple review at least once before public ship

## Build Order (iOS first)

1. Supabase schema + auth (small but foundational)
2. iOS: map + GPS recording + local persistence (offline-only)
3. iOS: destination pinning + breadcrumb visualization
4. iOS: sync to Supabase + shared map view
5. iOS: Follow Trail mode (compass + drift)
6. iOS: safety features (back-to-start, off-trail, waypoints)
7. TestFlight → iterate
8. Android port — same feature order, leaning on stable backend and proven UX

## Out of Scope for v1

- Live hike broadcasting (added in v2)
- Multi-day backpacking optimizations
- Topographic / satellite tile providers
- Group/follower social graph
- Teacher/student dashboards
- Photo uploads on waypoints
