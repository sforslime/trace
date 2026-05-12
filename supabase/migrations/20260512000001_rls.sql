-- Row Level Security
-- Enforces the design rule: trails public, waypoints private unless shared.

alter table public.profiles enable row level security;
alter table public.hikes enable row level security;
alter table public.waypoints enable row level security;

-- profiles: anyone can read, only owner can update
create policy "profiles are readable by anyone"
    on public.profiles for select
    using (true);

create policy "users update own profile"
    on public.profiles for update
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- hikes: published hikes readable by anyone; owner can do anything to their own
create policy "published hikes readable by anyone"
    on public.hikes for select
    using (is_published = true);

create policy "owner reads own hikes"
    on public.hikes for select
    using (auth.uid() = user_id);

create policy "owner inserts own hikes"
    on public.hikes for insert
    with check (auth.uid() = user_id);

create policy "owner updates own hikes"
    on public.hikes for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "owner deletes own hikes"
    on public.hikes for delete
    using (auth.uid() = user_id);

-- waypoints: public waypoints readable by anyone; private ones only by owner
create policy "public waypoints readable by anyone"
    on public.waypoints for select
    using (is_public = true);

create policy "owner reads own waypoints"
    on public.waypoints for select
    using (auth.uid() = user_id);

create policy "owner inserts own waypoints"
    on public.waypoints for insert
    with check (auth.uid() = user_id);

create policy "owner updates own waypoints"
    on public.waypoints for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "owner deletes own waypoints"
    on public.waypoints for delete
    using (auth.uid() = user_id);
