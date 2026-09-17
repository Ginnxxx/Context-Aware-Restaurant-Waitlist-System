-- QueueLess milestone 12: Allow authenticated users to view active queue tickets
-- and provide get_venue_waiting_count RPC so customer apps see accurate waiting parties.

-- 1. Permissive policy allowing customers to see tickets currently waiting in queue
drop policy if exists "customers view active queue tickets" on public.tickets;
create policy "customers view active queue tickets"
  on public.tickets for select to authenticated
  using (status in ('waiting', 'approaching', 'called'));

-- 2. Dedicated RPC for getting venue queue depth
create or replace function public.get_venue_waiting_count(target_venue uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.tickets
  where venue_id = target_venue
    and status in ('waiting', 'approaching', 'called');
$$;

grant execute on function public.get_venue_waiting_count(uuid) to anon, authenticated, service_role;
