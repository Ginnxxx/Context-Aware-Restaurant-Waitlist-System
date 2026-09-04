-- QueueLess milestone: smart capacity-aware calling and pre-allocation
-- Prevents calling parties when physical seats are unavailable, unless overridden by staff.
-- Run after 202608310009_staff_operations_hardening.sql.

create or replace function public.call_next_party(
  target_venue uuid,
  force_call boolean default false
)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_venue public.venues;
  selected_ticket public.tickets;
  occupied_seats integer;
  reserved_seats integer;
  committed_seats integer;
  available_seats integer;
begin
  if not public.is_venue_staff(target_venue) then
    raise exception 'Staff permission required';
  end if;

  select * into selected_venue
  from public.venues
  where id = target_venue
  for update;

  if not found then raise exception 'Venue not found'; end if;

  -- Calculate currently dining seats
  select coalesce(sum(party_size), 0)::integer into occupied_seats
  from public.tickets
  where venue_id = target_venue
    and status = 'seated'
    and departed_at is null;

  -- Calculate already called / arrived seats (committed for incoming guests)
  select coalesce(sum(party_size), 0)::integer into reserved_seats
  from public.tickets
  where venue_id = target_venue
    and status in ('called', 'arrived');

  committed_seats := occupied_seats + reserved_seats;
  available_seats := greatest(0, selected_venue.seat_capacity - committed_seats);

  if force_call then
    -- Override: select top sequence waiting/approaching party
    select * into selected_ticket
    from public.tickets
    where venue_id = target_venue and status in ('waiting', 'approaching')
    order by sequence
    for update skip locked
    limit 1;
  else
    -- Smart table-fit: find the first waiting party whose size fits within available seats
    select * into selected_ticket
    from public.tickets
    where venue_id = target_venue
      and status in ('waiting', 'approaching')
      and party_size <= available_seats
    order by sequence
    for update skip locked
    limit 1;

    -- If no party fits, check if there are waiting parties that are simply too large
    if not found then
      if exists (
        select 1 from public.tickets
        where venue_id = target_venue and status in ('waiting', 'approaching')
      ) then
        raise exception 'Not enough seats available (% available of % capacity). Wait for tables to clear or override.',
          available_seats, selected_venue.seat_capacity;
      else
        raise exception 'No waiting parties';
      end if;
    end if;
  end if;

  if selected_ticket is null or selected_ticket.id is null then
    raise exception 'No waiting parties';
  end if;

  update public.tickets
  set status = 'called', called_at = now(), updated_at = now()
  where id = selected_ticket.id
  returning * into selected_ticket;

  insert into public.notification_jobs (ticket_id, kind)
  values (selected_ticket.id, 'table_ready');

  return selected_ticket;
end;
$$;

create or replace function public.call_next_party(target_venue uuid)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.call_next_party(target_venue, false);
end;
$$;

revoke all on function public.call_next_party(uuid, boolean) from public, anon;
revoke all on function public.call_next_party(uuid) from public, anon;
grant execute on function public.call_next_party(uuid, boolean) to authenticated;
grant execute on function public.call_next_party(uuid) to authenticated;
