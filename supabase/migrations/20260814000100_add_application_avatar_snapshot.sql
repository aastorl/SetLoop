alter table public.applications
add column if not exists applicant_avatar_url text;

update public.applications applications
set applicant_avatar_url = profiles.avatar_url
from public.profiles profiles
where profiles.id = applications.applicant_user_id
  and applications.applicant_avatar_url is distinct from profiles.avatar_url;

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
    new.applicant_avatar_url = applicant_profile.avatar_url;
    return new;
end;
$$;
