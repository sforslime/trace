-- Extend hikes_in_bbox to return the author's profile (username + display_name).
-- Replaces the function in 20260512000002_bbox_query.sql.
-- DROP is required because CREATE OR REPLACE refuses to change the RETURNS TABLE
-- shape.

drop function if exists public.hikes_in_bbox(double precision, double precision, double precision, double precision);

create function public.hikes_in_bbox(
    min_lng double precision,
    min_lat double precision,
    max_lng double precision,
    max_lat double precision
)
returns table (
    id uuid,
    user_id uuid,
    username text,
    display_name text,
    title text,
    distance_meters numeric,
    duration_seconds integer,
    destination_name text,
    destination_lng double precision,
    destination_lat double precision,
    trail_geojson json
)
language sql
stable
security definer
set search_path = public
as $$
    select
        h.id,
        h.user_id,
        p.username,
        p.display_name,
        h.title,
        h.distance_meters,
        h.duration_seconds,
        h.destination_name,
        st_x(h.destination_point::geometry) as destination_lng,
        st_y(h.destination_point::geometry) as destination_lat,
        st_asgeojson(h.trail::geometry)::json as trail_geojson
    from public.hikes h
    left join public.profiles p on p.id = h.user_id
    where h.is_published = true
      and h.trail && st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography;
$$;
