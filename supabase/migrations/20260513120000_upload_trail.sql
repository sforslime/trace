-- RPC: upload a completed trail from the iOS client.
-- iOS sends coords as a jsonb array of [lng, lat] pairs; the function
-- builds a PostGIS LINESTRING server-side, inserts the hike row, and
-- (if a destination is included) inserts a destination waypoint that
-- is public alongside the public trail.

create or replace function public.upload_trail(
    trail_id uuid,
    started_at timestamptz,
    ended_at timestamptz,
    coords jsonb,
    distance_meters numeric,
    step_count integer,
    duration_seconds integer,
    title text default null,
    destination_lng double precision default null,
    destination_lat double precision default null,
    destination_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    caller uuid := auth.uid();
    line geography(linestring, 4326);
    inserted_id uuid;
begin
    if caller is null then
        raise exception 'authentication required';
    end if;

    if jsonb_array_length(coords) < 2 then
        raise exception 'trail needs at least 2 points';
    end if;

    -- Build a LINESTRING from the jsonb array of [lng, lat] pairs.
    select st_makeline(
        st_makepoint((c->>0)::double precision, (c->>1)::double precision)
    )::geography
    into line
    from jsonb_array_elements(coords) as c;

    insert into public.hikes (
        id, user_id, title, started_at, ended_at,
        distance_meters, step_count, duration_seconds,
        trail, destination_point, destination_name, is_published
    ) values (
        trail_id, caller, title, started_at, ended_at,
        distance_meters, step_count, duration_seconds,
        line,
        case
            when destination_lng is not null and destination_lat is not null
                then st_makepoint(destination_lng, destination_lat)::geography
            else null
        end,
        destination_name,
        true
    )
    returning id into inserted_id;

    if destination_lng is not null and destination_lat is not null then
        insert into public.waypoints (
            hike_id, user_id, location, name, is_public, is_destination
        ) values (
            inserted_id, caller,
            st_makepoint(destination_lng, destination_lat)::geography,
            destination_name,
            true,
            true
        );
    end if;

    return inserted_id;
end;
$$;
