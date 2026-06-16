begin;

drop trigger if exists applications_notify_change on public.applications;
drop function if exists public.notify_application_change();

delete from public.notifications
where type::text in ('invite_received', 'invite_accepted', 'invite_rejected');

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
            and table_name = 'notifications'
            and column_name = 'related_invite_id'
    ) then
        delete from public.notifications
        where related_invite_id is not null;
    end if;
end;
$$;

alter table if exists public.notifications
drop column if exists related_invite_id;

drop table if exists public.invites cascade;
drop function if exists public.prepare_invite();
drop function if exists public.notify_invite_change();
drop function if exists public.close_booking_after_invite_acceptance();

drop trigger if exists applications_close_booking_after_acceptance on public.applications;
drop function if exists public.close_booking_after_application_acceptance();

create type public.notification_type_current as enum (
    'application_received',
    'application_accepted',
    'application_rejected'
);

alter table public.notifications
alter column type type public.notification_type_current
using type::text::public.notification_type_current;

drop type public.notification_type;
alter type public.notification_type_current rename to notification_type;

grant usage on type public.notification_type to authenticated;
grant usage on type public.notification_type to service_role;

create or replace function public.close_booking_after_application_acceptance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.gigs
    set status = 'booked',
        updated_at = now()
    where id = new.gig_id
        and status = 'open';

    update public.applications
    set status = 'rejected',
        updated_at = now()
    where gig_id = new.gig_id
        and id <> new.id
        and status = 'pending';

    return new;
end;
$$;

create trigger applications_close_booking_after_acceptance
after update on public.applications
for each row
when (old.status is distinct from new.status and new.status = 'accepted')
execute function public.close_booking_after_application_acceptance();

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
        or new.related_application_id is distinct from old.related_application_id then
        raise exception 'notification immutable fields cannot be updated';
    end if;

    if old.is_read = true and new.is_read = false then
        raise exception 'read notifications cannot be marked unread';
    end if;

    return new;
end;
$$;

grant execute on function public.close_booking_after_application_acceptance() to authenticated;
grant execute on function public.notify_application_change() to authenticated;
grant execute on function public.prevent_notification_mutation() to authenticated;
grant execute on function public.close_booking_after_application_acceptance() to service_role;
grant execute on function public.notify_application_change() to service_role;
grant execute on function public.prevent_notification_mutation() to service_role;

commit;
