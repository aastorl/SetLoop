drop policy if exists "users can delete their notifications" on public.notifications;
create policy "users can delete their notifications"
on public.notifications
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "users can delete historical applications" on public.applications;
create policy "users can delete historical applications"
on public.applications
for delete
to authenticated
using (
    status <> 'pending'
    and exists (
        select 1
        from public.gigs
        where gigs.id = applications.gig_id
          and gigs.performance_date < date_trunc('day', now())
          and (
              applications.applicant_user_id = auth.uid()
              or gigs.host_user_id = auth.uid()
          )
    )
);

grant delete on public.notifications to authenticated;
grant delete on public.applications to authenticated;
