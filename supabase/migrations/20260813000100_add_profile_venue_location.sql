alter table public.profiles
    add column if not exists venue_place_name text,
    add column if not exists venue_latitude double precision,
    add column if not exists venue_longitude double precision;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'profiles_venue_latitude_range'
    ) then
        alter table public.profiles
            add constraint profiles_venue_latitude_range
            check (venue_latitude is null or venue_latitude between -90 and 90);
    end if;

    if not exists (
        select 1
        from pg_constraint
        where conname = 'profiles_venue_longitude_range'
    ) then
        alter table public.profiles
            add constraint profiles_venue_longitude_range
            check (venue_longitude is null or venue_longitude between -180 and 180);
    end if;
end $$;

create index if not exists profiles_venue_location_idx
    on public.profiles (venue_latitude, venue_longitude)
    where venue_latitude is not null and venue_longitude is not null;
