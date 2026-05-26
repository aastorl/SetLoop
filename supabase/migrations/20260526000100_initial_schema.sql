create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create type public.user_role as enum ('musician', 'venue', 'dj');
create type public.gig_status as enum ('open', 'booked', 'cancelled');
create type public.booking_status as enum ('pending', 'accepted', 'rejected', 'withdrawn');
create type public.notification_type as enum (
    'application_received',
    'application_accepted',
    'application_rejected',
    'invite_received',
    'invite_accepted',
    'invite_rejected'
);

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text not null,
    display_name text not null,
    role public.user_role not null,
    city text not null,
    venue_address text,
    bio text,
    avatar_url text,
    genres text[] not null default '{}',
    instruments text[] not null default '{}',
    instrument_counts jsonb not null default '{}'::jsonb,
    venue_capacity integer,
    is_premium boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_email_not_blank check (length(btrim(email)) > 3),
    constraint profiles_display_name_not_blank check (length(btrim(display_name)) > 0),
    constraint profiles_city_not_blank check (length(btrim(city)) > 0),
    constraint profiles_venue_capacity_positive check (venue_capacity is null or venue_capacity > 0),
    constraint profiles_instrument_counts_object check (jsonb_typeof(instrument_counts) = 'object')
);

create table public.venues (
    id uuid primary key default extensions.gen_random_uuid(),
    owner_id uuid not null references public.profiles(id) on delete cascade,
    name text not null,
    city text not null,
    address text not null,
    capacity integer,
    description text,
    genres text[] not null default '{}',
    image_url text,
    latitude double precision,
    longitude double precision,
    is_verified boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint venues_owner_unique unique (owner_id),
    constraint venues_name_not_blank check (length(btrim(name)) > 0),
    constraint venues_city_not_blank check (length(btrim(city)) > 0),
    constraint venues_address_not_blank check (length(btrim(address)) > 0),
    constraint venues_capacity_positive check (capacity is null or capacity > 0),
    constraint venues_latitude_range check (latitude is null or latitude between -90 and 90),
    constraint venues_longitude_range check (longitude is null or longitude between -180 and 180)
);

create table public.gigs (
    id uuid primary key default extensions.gen_random_uuid(),
    venue_id uuid references public.venues(id) on delete set null,
    host_user_id uuid not null references public.profiles(id) on delete cascade,
    title text not null,
    venue_name text,
    city text not null,
    performance_date timestamptz not null,
    duration_minutes integer,
    budget_min integer,
    budget_max integer,
    currency text not null default 'EUR',
    role_needed public.user_role not null,
    required_genres text[] not null default '{}',
    description text,
    status public.gig_status not null default 'open',
    image_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint gigs_title_not_blank check (length(btrim(title)) > 0),
    constraint gigs_city_not_blank check (length(btrim(city)) > 0),
    constraint gigs_duration_positive check (duration_minutes is null or duration_minutes > 0),
    constraint gigs_budget_min_positive check (budget_min is null or budget_min >= 0),
    constraint gigs_budget_max_positive check (budget_max is null or budget_max >= 0),
    constraint gigs_budget_range check (budget_min is null or budget_max is null or budget_max >= budget_min),
    constraint gigs_currency_iso check (currency ~ '^[A-Z]{3}$'),
    constraint gigs_role_needed_talent check (role_needed in ('musician', 'dj'))
);

create table public.applications (
    id uuid primary key default extensions.gen_random_uuid(),
    gig_id uuid not null references public.gigs(id) on delete cascade,
    applicant_user_id uuid not null references public.profiles(id) on delete cascade,
    applicant_display_name text not null,
    applicant_role public.user_role not null,
    applicant_city text not null,
    message text not null default '',
    status public.booking_status not null default 'pending',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint applications_unique_applicant_per_gig unique (gig_id, applicant_user_id),
    constraint applications_applicant_is_talent check (applicant_role in ('musician', 'dj')),
    constraint applications_display_name_not_blank check (length(btrim(applicant_display_name)) > 0),
    constraint applications_city_not_blank check (length(btrim(applicant_city)) > 0)
);

create table public.invites (
    id uuid primary key default extensions.gen_random_uuid(),
    gig_id uuid not null references public.gigs(id) on delete cascade,
    host_user_id uuid not null references public.profiles(id) on delete cascade,
    host_display_name text not null,
    talent_user_id uuid not null references public.profiles(id) on delete cascade,
    talent_display_name text not null,
    talent_role public.user_role not null,
    talent_city text not null,
    message text not null default '',
    status public.booking_status not null default 'pending',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint invites_unique_talent_per_gig unique (gig_id, host_user_id, talent_user_id),
    constraint invites_host_not_talent check (host_user_id <> talent_user_id),
    constraint invites_talent_is_talent check (talent_role in ('musician', 'dj')),
    constraint invites_host_display_name_not_blank check (length(btrim(host_display_name)) > 0),
    constraint invites_talent_display_name_not_blank check (length(btrim(talent_display_name)) > 0),
    constraint invites_talent_city_not_blank check (length(btrim(talent_city)) > 0)
);

create table public.notifications (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references public.profiles(id) on delete cascade,
    type public.notification_type not null,
    title text not null,
    body text not null,
    created_at timestamptz not null default now(),
    is_read boolean not null default false,
    related_gig_id uuid references public.gigs(id) on delete set null,
    related_application_id uuid references public.applications(id) on delete set null,
    related_invite_id uuid references public.invites(id) on delete set null,
    constraint notifications_title_not_blank check (length(btrim(title)) > 0),
    constraint notifications_body_not_blank check (length(btrim(body)) > 0)
);

create table public.reviews (
    id uuid primary key default extensions.gen_random_uuid(),
    reviewer_id uuid not null references public.profiles(id) on delete cascade,
    reviewee_id uuid not null references public.profiles(id) on delete cascade,
    gig_id uuid references public.gigs(id) on delete set null,
    rating integer not null,
    comment text not null,
    created_at timestamptz not null default now(),
    constraint reviews_no_self_review check (reviewer_id <> reviewee_id),
    constraint reviews_rating_range check (rating between 1 and 5),
    constraint reviews_comment_not_blank check (length(btrim(comment)) > 0)
);

create unique index profiles_email_unique_idx on public.profiles (lower(email));
create index profiles_role_city_idx on public.profiles (role, lower(city));
create index profiles_genres_idx on public.profiles using gin (genres);
create index profiles_instruments_idx on public.profiles using gin (instruments);

create index venues_city_idx on public.venues (lower(city));
create index venues_genres_idx on public.venues using gin (genres);
create index venues_verified_idx on public.venues (is_verified);

create index gigs_host_user_id_idx on public.gigs (host_user_id);
create index gigs_venue_id_idx on public.gigs (venue_id);
create index gigs_explore_idx on public.gigs (status, role_needed, lower(city), performance_date);
create index gigs_required_genres_idx on public.gigs using gin (required_genres);

create index applications_gig_status_idx on public.applications (gig_id, status, created_at desc);
create index applications_applicant_status_idx on public.applications (applicant_user_id, status, created_at desc);

create index invites_host_status_idx on public.invites (host_user_id, status, created_at desc);
create index invites_talent_status_idx on public.invites (talent_user_id, status, created_at desc);
create index invites_gig_status_idx on public.invites (gig_id, status, created_at desc);

create index notifications_user_unread_idx on public.notifications (user_id, is_read, created_at desc);
create index notifications_related_gig_idx on public.notifications (related_gig_id);
create index notifications_related_application_idx on public.notifications (related_application_id);
create index notifications_related_invite_idx on public.notifications (related_invite_id);

create index reviews_reviewee_created_idx on public.reviews (reviewee_id, created_at desc);
create index reviews_reviewer_created_idx on public.reviews (reviewer_id, created_at desc);
create unique index reviews_one_per_gig_idx on public.reviews (reviewer_id, reviewee_id, gig_id)
    where gig_id is not null;
create unique index reviews_one_unlinked_idx on public.reviews (reviewer_id, reviewee_id)
    where gig_id is null;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger venues_set_updated_at
before update on public.venues
for each row execute function public.set_updated_at();

create trigger gigs_set_updated_at
before update on public.gigs
for each row execute function public.set_updated_at();

create trigger applications_set_updated_at
before update on public.applications
for each row execute function public.set_updated_at();

create trigger invites_set_updated_at
before update on public.invites
for each row execute function public.set_updated_at();

create or replace function public.prevent_profile_privilege_changes()
returns trigger
language plpgsql
as $$
begin
    if auth.uid() is null or auth.role() = 'service_role' then
        return new;
    end if;

    if new.role <> old.role then
        raise exception 'profile role cannot be changed by clients';
    end if;

    if new.is_premium <> old.is_premium then
        raise exception 'profile premium flag cannot be changed by clients';
    end if;

    if lower(new.email) <> lower(old.email) then
        raise exception 'profile email cannot be changed by clients';
    end if;

    return new;
end;
$$;

create trigger profiles_prevent_privilege_changes
before update on public.profiles
for each row execute function public.prevent_profile_privilege_changes();

create or replace function public.prevent_venue_verification_changes()
returns trigger
language plpgsql
as $$
begin
    if auth.uid() is null or auth.role() = 'service_role' then
        return new;
    end if;

    if new.is_verified <> old.is_verified then
        raise exception 'venue verification cannot be changed by clients';
    end if;

    return new;
end;
$$;

create trigger venues_prevent_verification_changes
before update on public.venues
for each row execute function public.prevent_venue_verification_changes();

create or replace function public.profile_role(profile_id uuid)
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
    select role from public.profiles where id = profile_id;
$$;

create or replace function public.is_venue_user(profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.profiles
        where id = profile_id and role = 'venue'
    );
$$;

create or replace function public.is_talent_user(profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.profiles
        where id = profile_id and role in ('musician', 'dj')
    );
$$;

create or replace function public.is_gig_host(target_gig_id uuid, profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.gigs
        where id = target_gig_id and host_user_id = profile_id
    );
$$;

create or replace function public.gig_role_needed(target_gig_id uuid)
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
    select role_needed from public.gigs where id = target_gig_id;
$$;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    metadata_role public.user_role;
begin
    metadata_role = case
        when new.raw_user_meta_data ->> 'role' in ('musician', 'venue', 'dj')
            then (new.raw_user_meta_data ->> 'role')::public.user_role
        else 'musician'::public.user_role
    end;

    insert into public.profiles (
        id,
        email,
        display_name,
        role,
        city
    )
    values (
        new.id,
        coalesce(new.email, ''),
        coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(coalesce(new.email, 'setloop_user'), '@', 1)),
        metadata_role,
        coalesce(nullif(btrim(new.raw_user_meta_data ->> 'city'), ''), 'Por definir')
    )
    on conflict (id) do update
    set email = excluded.email,
        updated_at = now();

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

create or replace function public.validate_venue_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.profile_role(new.owner_id) <> 'venue' then
        raise exception 'venues.owner_id must reference a venue profile';
    end if;

    return new;
end;
$$;

create trigger venues_validate_owner
before insert or update on public.venues
for each row execute function public.validate_venue_owner();

create or replace function public.validate_gig_host()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.profile_role(new.host_user_id) <> 'venue' then
        raise exception 'gigs.host_user_id must reference a venue profile';
    end if;

    if new.venue_id is not null and not exists (
        select 1 from public.venues
        where id = new.venue_id and owner_id = new.host_user_id
    ) then
        raise exception 'gigs.venue_id must belong to host_user_id';
    end if;

    return new;
end;
$$;

create trigger gigs_validate_host
before insert or update on public.gigs
for each row execute function public.validate_gig_host();

create or replace function public.prepare_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    applicant_profile public.profiles%rowtype;
    target_gig public.gigs%rowtype;
begin
    select * into applicant_profile
    from public.profiles
    where id = new.applicant_user_id;

    if not found or applicant_profile.role not in ('musician', 'dj') then
        raise exception 'applications.applicant_user_id must reference a talent profile';
    end if;

    select * into target_gig
    from public.gigs
    where id = new.gig_id;

    if not found then
        raise exception 'applications.gig_id must reference an existing gig';
    end if;

    if tg_op = 'INSERT' and target_gig.status <> 'open' then
        raise exception 'applications can only be created for open gigs';
    end if;

    if target_gig.host_user_id = new.applicant_user_id then
        raise exception 'profiles cannot apply to their own gigs';
    end if;

    if target_gig.role_needed <> applicant_profile.role then
        raise exception 'application role must match gig role_needed';
    end if;

    if tg_op = 'UPDATE' then
        if new.id <> old.id
            or new.gig_id <> old.gig_id
            or new.applicant_user_id <> old.applicant_user_id
            or new.message <> old.message then
            raise exception 'application immutable fields cannot be updated';
        end if;

        if old.status <> new.status and old.status <> 'pending' then
            raise exception 'only pending applications can change status';
        end if;
    end if;

    new.applicant_display_name = applicant_profile.display_name;
    new.applicant_role = applicant_profile.role;
    new.applicant_city = applicant_profile.city;
    return new;
end;
$$;

create trigger applications_prepare
before insert or update on public.applications
for each row execute function public.prepare_application();

create or replace function public.prepare_invite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    host_profile public.profiles%rowtype;
    talent_profile public.profiles%rowtype;
    target_gig public.gigs%rowtype;
begin
    select * into host_profile
    from public.profiles
    where id = new.host_user_id;

    if not found or host_profile.role <> 'venue' then
        raise exception 'invites.host_user_id must reference a venue profile';
    end if;

    select * into talent_profile
    from public.profiles
    where id = new.talent_user_id;

    if not found or talent_profile.role not in ('musician', 'dj') then
        raise exception 'invites.talent_user_id must reference a talent profile';
    end if;

    select * into target_gig
    from public.gigs
    where id = new.gig_id;

    if not found then
        raise exception 'invites.gig_id must reference an existing gig';
    end if;

    if tg_op = 'INSERT' and target_gig.status <> 'open' then
        raise exception 'invites can only be created for open gigs';
    end if;

    if target_gig.host_user_id <> new.host_user_id then
        raise exception 'invites.host_user_id must own the gig';
    end if;

    if target_gig.role_needed <> talent_profile.role then
        raise exception 'invite role must match gig role_needed';
    end if;

    if tg_op = 'UPDATE' then
        if new.id <> old.id
            or new.gig_id <> old.gig_id
            or new.host_user_id <> old.host_user_id
            or new.talent_user_id <> old.talent_user_id
            or new.message <> old.message then
            raise exception 'invite immutable fields cannot be updated';
        end if;

        if old.status <> new.status and old.status <> 'pending' then
            raise exception 'only pending invites can change status';
        end if;
    end if;

    new.host_display_name = host_profile.display_name;
    new.talent_display_name = talent_profile.display_name;
    new.talent_role = talent_profile.role;
    new.talent_city = talent_profile.city;
    return new;
end;
$$;

create trigger invites_prepare
before insert or update on public.invites
for each row execute function public.prepare_invite();

create or replace function public.notify_application_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    target_gig public.gigs%rowtype;
    venue_label text;
begin
    select * into target_gig from public.gigs where id = new.gig_id;
    venue_label = coalesce(target_gig.venue_name, 'tu local');

    if tg_op = 'INSERT' then
        insert into public.notifications (
            user_id,
            type,
            title,
            body,
            related_gig_id,
            related_application_id
        )
        values (
            target_gig.host_user_id,
            'application_received',
            'Nueva candidatura para ' || target_gig.title,
            new.applicant_display_name || ' quiere actuar en ' || venue_label || '.',
            target_gig.id,
            new.id
        );
        return new;
    end if;

    if old.status <> new.status and new.status in ('accepted', 'rejected') then
        insert into public.notifications (
            user_id,
            type,
            title,
            body,
            related_gig_id,
            related_application_id
        )
        values (
            new.applicant_user_id,
            case
                when new.status = 'accepted' then 'application_accepted'::public.notification_type
                else 'application_rejected'::public.notification_type
            end,
            case
                when new.status = 'accepted' then 'Solicitud aceptada'
                else 'Solicitud rechazada'
            end,
            case
                when new.status = 'accepted'
                    then 'Tu candidatura para ' || target_gig.title || ' en ' || venue_label || ' ha sido aceptada.'
                else 'Tu candidatura para ' || target_gig.title || ' en ' || venue_label || ' no ha seguido adelante.'
            end,
            target_gig.id,
            new.id
        );
    end if;

    return new;
end;
$$;

create trigger applications_notify_change
after insert or update on public.applications
for each row execute function public.notify_application_change();

create or replace function public.notify_invite_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    target_gig public.gigs%rowtype;
    venue_label text;
begin
    select * into target_gig from public.gigs where id = new.gig_id;
    venue_label = coalesce(target_gig.venue_name, target_gig.city);

    if tg_op = 'INSERT' then
        insert into public.notifications (
            user_id,
            type,
            title,
            body,
            related_gig_id,
            related_invite_id
        )
        values (
            new.talent_user_id,
            'invite_received',
            'Nueva invitacion para ' || target_gig.title,
            new.host_display_name || ' quiere contar contigo en ' || venue_label || '.',
            target_gig.id,
            new.id
        );
        return new;
    end if;

    if old.status <> new.status and new.status in ('accepted', 'rejected') then
        insert into public.notifications (
            user_id,
            type,
            title,
            body,
            related_gig_id,
            related_invite_id
        )
        values (
            new.host_user_id,
            case
                when new.status = 'accepted' then 'invite_accepted'::public.notification_type
                else 'invite_rejected'::public.notification_type
            end,
            case
                when new.status = 'accepted' then 'Invitacion aceptada'
                else 'Invitacion rechazada'
            end,
            case
                when new.status = 'accepted'
                    then new.talent_display_name || ' ha aceptado tu invitacion para ' || target_gig.title || ' en ' || venue_label || '.'
                else new.talent_display_name || ' no seguira adelante con ' || target_gig.title || ' en ' || venue_label || '.'
            end,
            target_gig.id,
            new.id
        );
    end if;

    return new;
end;
$$;

create trigger invites_notify_change
after insert or update on public.invites
for each row execute function public.notify_invite_change();

create or replace function public.prevent_notification_mutation()
returns trigger
language plpgsql
as $$
begin
    if auth.role() = 'service_role' then
        return new;
    end if;

    if new.id <> old.id
        or new.user_id <> old.user_id
        or new.type <> old.type
        or new.title <> old.title
        or new.body <> old.body
        or new.created_at <> old.created_at
        or new.related_gig_id is distinct from old.related_gig_id
        or new.related_application_id is distinct from old.related_application_id
        or new.related_invite_id is distinct from old.related_invite_id then
        raise exception 'notification immutable fields cannot be updated';
    end if;

    if old.is_read = true and new.is_read = false then
        raise exception 'read notifications cannot be marked unread';
    end if;

    return new;
end;
$$;

create trigger notifications_prevent_mutation
before update on public.notifications
for each row execute function public.prevent_notification_mutation();

alter table public.profiles enable row level security;
alter table public.venues enable row level security;
alter table public.gigs enable row level security;
alter table public.applications enable row level security;
alter table public.invites enable row level security;
alter table public.notifications enable row level security;
alter table public.reviews enable row level security;

create policy "profiles are readable by authenticated users"
on public.profiles
for select
to authenticated
using (true);

create policy "users can insert their own profile"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

create policy "users can update their own profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "venues are readable by authenticated users"
on public.venues
for select
to authenticated
using (true);

create policy "venue users can insert their venue"
on public.venues
for insert
to authenticated
with check (owner_id = auth.uid() and public.is_venue_user(auth.uid()));

create policy "venue owners can update their venue"
on public.venues
for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid() and public.is_venue_user(auth.uid()));

create policy "venue owners can delete their venue"
on public.venues
for delete
to authenticated
using (owner_id = auth.uid());

create policy "gigs are readable by authenticated users"
on public.gigs
for select
to authenticated
using (true);

create policy "venue users can insert their gigs"
on public.gigs
for insert
to authenticated
with check (host_user_id = auth.uid() and public.is_venue_user(auth.uid()));

create policy "gig hosts can update their gigs"
on public.gigs
for update
to authenticated
using (host_user_id = auth.uid())
with check (host_user_id = auth.uid() and public.is_venue_user(auth.uid()));

create policy "gig hosts can delete their gigs"
on public.gigs
for delete
to authenticated
using (host_user_id = auth.uid());

create policy "applications are readable by applicant or gig host"
on public.applications
for select
to authenticated
using (
    applicant_user_id = auth.uid()
    or public.is_gig_host(gig_id, auth.uid())
);

create policy "talent can apply to matching gigs"
on public.applications
for insert
to authenticated
with check (
    applicant_user_id = auth.uid()
    and public.is_talent_user(auth.uid())
    and applicant_role = public.gig_role_needed(gig_id)
);

create policy "applicants can withdraw their applications"
on public.applications
for update
to authenticated
using (applicant_user_id = auth.uid() and status = 'pending')
with check (applicant_user_id = auth.uid() and status = 'withdrawn');

create policy "gig hosts can decide applications"
on public.applications
for update
to authenticated
using (public.is_gig_host(gig_id, auth.uid()) and status = 'pending')
with check (public.is_gig_host(gig_id, auth.uid()) and status in ('accepted', 'rejected'));

create policy "invites are readable by host or talent"
on public.invites
for select
to authenticated
using (
    host_user_id = auth.uid()
    or talent_user_id = auth.uid()
);

create policy "venue users can invite matching talent"
on public.invites
for insert
to authenticated
with check (
    host_user_id = auth.uid()
    and public.is_venue_user(auth.uid())
    and public.is_talent_user(talent_user_id)
    and public.is_gig_host(gig_id, auth.uid())
    and talent_role = public.gig_role_needed(gig_id)
);

create policy "invited talent can answer invites"
on public.invites
for update
to authenticated
using (talent_user_id = auth.uid() and status = 'pending')
with check (talent_user_id = auth.uid() and status in ('accepted', 'rejected'));

create policy "hosts can withdraw pending invites"
on public.invites
for update
to authenticated
using (host_user_id = auth.uid() and status = 'pending')
with check (host_user_id = auth.uid() and status = 'withdrawn');

create policy "users can read their notifications"
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

create policy "users can mark their notifications read"
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "reviews are readable by authenticated users"
on public.reviews
for select
to authenticated
using (true);

create policy "users can create their own reviews"
on public.reviews
for insert
to authenticated
with check (reviewer_id = auth.uid() and reviewee_id <> auth.uid());

create policy "users can update their own reviews"
on public.reviews
for update
to authenticated
using (reviewer_id = auth.uid())
with check (reviewer_id = auth.uid() and reviewee_id <> auth.uid());

create policy "users can delete their own reviews"
on public.reviews
for delete
to authenticated
using (reviewer_id = auth.uid());

grant usage on schema public to authenticated;
grant usage on type public.user_role to authenticated;
grant usage on type public.gig_status to authenticated;
grant usage on type public.booking_status to authenticated;
grant usage on type public.notification_type to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.venues to authenticated;
grant select, insert, update, delete on public.gigs to authenticated;
grant select, insert, update on public.applications to authenticated;
grant select, insert, update on public.invites to authenticated;
grant select, update on public.notifications to authenticated;
grant select, insert, update, delete on public.reviews to authenticated;
grant execute on all functions in schema public to authenticated;

grant usage on schema public to service_role;
grant usage on type public.user_role to service_role;
grant usage on type public.gig_status to service_role;
grant usage on type public.booking_status to service_role;
grant usage on type public.notification_type to service_role;
grant all on all tables in schema public to service_role;
grant all on all routines in schema public to service_role;
