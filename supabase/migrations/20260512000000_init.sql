-- Offline Hike Tracker — initial schema
-- Tables: profiles, hikes, waypoints
-- Geometry stored as PostGIS geography (SRID 4326, WGS84 — matches GPS)

create extension if not exists postgis;

-- profiles mirror auth.users, one row per signed-up user
create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    username text unique not null,
    display_name text,
    created_at timestamptz not null default now()
);

-- a hike is the full record of one outing
-- trail is public by default once uploaded (per design); is_published gives us
-- a future toggle if we ever want soft-private hikes
create table public.hikes (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    title text,
    started_at timestamptz not null,
    ended_at timestamptz not null,
    distance_meters numeric(10, 2) not null default 0,
    step_count integer not null default 0,
    duration_seconds integer not null default 0,
    trail geography(linestring, 4326) not null,
    destination_point geography(point, 4326),
    destination_name text,
    is_published boolean not null default true,
    created_at timestamptz not null default now()
);

-- waypoints are personal markers dropped during a hike
-- private by default; user toggles is_public to share to the shared map
create table public.waypoints (
    id uuid primary key default gen_random_uuid(),
    hike_id uuid not null references public.hikes(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    location geography(point, 4326) not null,
    name text,
    note text,
    is_public boolean not null default false,
    created_at timestamptz not null default now()
);

-- spatial indexes for bounding-box queries on the shared map
create index hikes_trail_gix on public.hikes using gist (trail);
create index hikes_destination_gix on public.hikes using gist (destination_point);
create index waypoints_location_gix on public.waypoints using gist (location);

-- lookup indexes
create index hikes_user_id_idx on public.hikes (user_id);
create index hikes_published_idx on public.hikes (is_published) where is_published;
create index waypoints_hike_id_idx on public.waypoints (hike_id);
create index waypoints_user_id_idx on public.waypoints (user_id);
create index waypoints_public_idx on public.waypoints (is_public) where is_public;

-- auto-create a profile row when a new auth user signs up
-- username defaults to the user's email local-part; user can change later
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, username, display_name)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)) || '_' || substr(new.id::text, 1, 6),
        coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
    );
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();
