-- Add is_destination flag to waypoints.
-- The upload_trail RPC already inserts into waypoints(..., is_destination)
-- when a trail has a destination; without this column the whole RPC throws
-- and the hike row never lands.

alter table public.waypoints
    add column is_destination boolean not null default false;
