-- QueueLess milestone 11: Dedicated RPC for toggling venue queue status (open/paused).
-- Allows staff to reliably pause and reopen queues across all devices without RLS edge-cases.

create or replace function public.set_venue_queue_open(
  target_venue uuid,
  is_open boolean
)
returns public.venues
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_venue public.venues;
begin
  update public.venues set
    queue_open = is_open
  where id = target_venue
  returning * into updated_venue;

  if not found then
    raise exception 'Venue not found: %', target_venue;
  end if;

  return updated_venue;
end;
$$;

grant execute on function public.set_venue_queue_open(uuid, boolean) to anon, authenticated, service_role;
