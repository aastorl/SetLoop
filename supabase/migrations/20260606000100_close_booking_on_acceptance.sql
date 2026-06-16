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
        and status <> 'booked';

    update public.applications
    set status = 'rejected',
        updated_at = now()
    where gig_id = new.gig_id
        and id <> new.id
        and status = 'pending';

    update public.invites
    set status = 'rejected',
        updated_at = now()
    where gig_id = new.gig_id
        and status = 'pending';

    return new;
end;
$$;

drop trigger if exists applications_close_booking_after_acceptance on public.applications;
create trigger applications_close_booking_after_acceptance
after update on public.applications
for each row
when (old.status is distinct from new.status and new.status = 'accepted')
execute function public.close_booking_after_application_acceptance();

create or replace function public.close_booking_after_invite_acceptance()
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
        and status <> 'booked';

    update public.applications
    set status = 'rejected',
        updated_at = now()
    where gig_id = new.gig_id
        and status = 'pending';

    update public.invites
    set status = 'rejected',
        updated_at = now()
    where gig_id = new.gig_id
        and id <> new.id
        and status = 'pending';

    return new;
end;
$$;

drop trigger if exists invites_close_booking_after_acceptance on public.invites;
create trigger invites_close_booking_after_acceptance
after update on public.invites
for each row
when (old.status is distinct from new.status and new.status = 'accepted')
execute function public.close_booking_after_invite_acceptance();
