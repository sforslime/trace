-- RPC: fetch trails and destinations inside a bounding box.
-- Called by the iOS app when the shared map's visible region changes.
-- Returns only published hikes; the map view doesn't render unpublished ones.

create or replace function public.hikes_in_bbox(
    min_lng double precision,
    min_lat double precision,
    max_lng double precision,
    max_lat double precision
)
returns table (
    id uuid,
    user_id uuid,
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
        h.title,
        h.distance_meters,
        h.duration_seconds,
        h.destination_name,
        st_x(h.destination_point::geometry) as destination_lng,
        st_y(h.destination_point::geometry) as destination_lat,
        st_asgeojson(h.trail::geometry)::json as trail_geojson
    from public.hikes h
    where h.is_published = true
      and h.trail && st_makeenvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography;
$$;
