begin;

create or replace function public.delete_historical_application(target_application_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    target_application public.applications%rowtype;
    target_gig public.gigs%rowtype;
    current_user_id uuid := auth.uid();
begin
    if current_user_id is null then
        raise exception 'authentication required'
            using errcode = '42501';
    end if;

    select * into target_application
    from public.applications
    where id = target_application_id;

    if not found then
        return;
    end if;

    select * into target_gig
    from public.gigs
    where id = target_application.gig_id;

    if not found then
        return;
    end if;

    if target_application.status = 'pending' then
        raise exception 'pending applications cannot be deleted';
    end if;

    if target_gig.performance_date::date >= current_date then
        raise exception 'applications can only be deleted after performance date';
    end if;

    if target_application.applicant_user_id <> current_user_id
        and target_gig.host_user_id <> current_user_id then
        raise exception 'not allowed to delete this application'
            using errcode = '42501';
    end if;

    delete from public.notifications
    where related_application_id = target_application_id;

    delete from public.applications
    where id = target_application_id;
end;
$$;

grant execute on function public.delete_historical_application(uuid) to authenticated;
grant execute on function public.delete_historical_application(uuid) to service_role;

commit;
