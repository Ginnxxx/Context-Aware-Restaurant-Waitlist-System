-- QueueLess milestone 8: auto-departure detection and table assignment.
-- Run after 202608150004_seat_capacity.sql.

alter table public.tickets
  add column if not exists table_label text,
  add column if not exists departure_reason text;

-- Update record_context_event to support seated departure and exit triggers
create or replace function public.record_context_event(
  target_ticket uuid,
  target_event_type text,
  target_distance_band text
)
returns public.context_events
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_ticket public.tickets;
  new_event public.context_events;
begin
  if target_event_type not in (
    'leave_now_recommended',
    'outer_geofence_entered',
    'arrival_geofence_entered',
    'outer_geofence_exited',
    'arrival_geofence_exited',
    'seated_guest_departed'
  ) then
    raise exception 'Unsupported context event';
  end if;

  if target_distance_band not in ('far', 'approaching', 'near') then
    raise exception 'Unsupported distance band';
  end if;

  select * into selected_ticket
  from public.tickets
  where id = target_ticket and owner_id = auth.uid()
  for update;

  if not found then raise exception 'Ticket not found'; end if;
  if selected_ticket.status not in ('waiting', 'approaching', 'called', 'seated') then
    raise exception 'Ticket is not active';
  end if;

  -- Ignore duplicate transitions reported within 30 seconds.
  select * into new_event
  from public.context_events
  where ticket_id = target_ticket
    and event_type = target_event_type
    and created_at > now() - interval '30 seconds'
  order by created_at desc
  limit 1;

  if found then return new_event; end if;

  insert into public.context_events (
    ticket_id, owner_id, event_type, distance_band
  ) values (
    target_ticket, auth.uid(), target_event_type, target_distance_band
  ) returning * into new_event;

  -- Context state transitions
  if target_event_type = 'outer_geofence_entered'
     and selected_ticket.status = 'waiting' then
    update public.tickets
    set status = 'approaching', approaching_at = now(), updated_at = now()
    where id = target_ticket;
  elsif target_event_type = 'outer_geofence_exited'
        and selected_ticket.status = 'approaching' then
    update public.tickets
    set status = 'waiting', approaching_at = null, updated_at = now()
    where id = target_ticket;
  elsif (target_event_type in ('seated_guest_departed', 'outer_geofence_exited', 'arrival_geofence_exited'))
        and selected_ticket.status = 'seated'
        and selected_ticket.departed_at is null then
    -- Automatic departure release on physical boundary exit
    update public.tickets
    set departed_at = now(),
        departure_reason = 'geofence_exit',
        updated_at = now()
    where id = target_ticket;
  end if;

  return new_event;
end;
$$;

-- Allow customer or staff to auto-release seated ticket
create or replace function public.auto_release_seated_ticket(
  target_ticket uuid,
  reason text default 'self_checkout'
)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_ticket public.tickets;
begin
  select * into selected_ticket
  from public.tickets
  where id = target_ticket
    and (owner_id = auth.uid() or public.is_venue_staff(venue_id))
  for update;

  if not found then raise exception 'Ticket not found or unauthorized'; end if;
  if selected_ticket.status <> 'seated' then
    raise exception 'Only seated parties can be released';
  end if;
  if selected_ticket.departed_at is not null then
    return selected_ticket;
  end if;

  update public.tickets set
    departed_at = now(),
    departure_reason = coalesce(reason, 'self_checkout'),
    updated_at = now()
  where id = target_ticket
  returning * into selected_ticket;

  return selected_ticket;
end;
$$;

-- Update staff_transition_ticket to accept table_label
create or replace function public.staff_transition_ticket(
  target_ticket uuid,
  next_status public.ticket_status,
  target_table_label text default null
)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_ticket public.tickets;
  venue_capacity integer;
  occupied_seats integer;
begin
  select * into selected_ticket
  from public.tickets
  where id = target_ticket
  for update;

  if not found then raise exception 'Ticket not found'; end if;
  if not public.is_venue_staff(selected_ticket.venue_id) then
    raise exception 'Staff permission required';
  end if;

  if not (
    (selected_ticket.status = 'called' and next_status in ('arrived', 'no_show')) or
    (selected_ticket.status = 'approaching' and next_status in ('called', 'cancelled')) or
    (selected_ticket.status = 'arrived' and next_status = 'seated') or
    (selected_ticket.status = 'waiting' and next_status = 'cancelled')
  ) then
    raise exception 'Invalid ticket transition from % to %', selected_ticket.status, next_status;
  end if;

  if next_status = 'seated' then
    -- Serialise seating changes so two hosts cannot exceed capacity together.
    select seat_capacity into venue_capacity
    from public.venues
    where id = selected_ticket.venue_id
    for update;

    select coalesce(sum(party_size), 0)::integer into occupied_seats
    from public.tickets
    where venue_id = selected_ticket.venue_id
      and status = 'seated'
      and departed_at is null;

    if occupied_seats + selected_ticket.party_size > venue_capacity then
      raise exception 'Not enough seats available (% occupied of %)',
        occupied_seats, venue_capacity;
    end if;
  end if;

  update public.tickets set
    status = next_status,
    table_label = case when next_status = 'seated' then coalesce(target_table_label, selected_ticket.table_label) else selected_ticket.table_label end,
    arrived_at = case when next_status = 'arrived' then now() else arrived_at end,
    completed_at = case
      when next_status in ('seated', 'cancelled', 'no_show') then now()
      else completed_at
    end,
    updated_at = now()
  where id = target_ticket
  returning * into selected_ticket;

  return selected_ticket;
end;
$$;

-- Update my_active_ticket_snapshot to include seated dining state and table_label
create or replace function public.my_active_ticket_snapshot(target_venue uuid)
returns table (
  id uuid,
  venue_id uuid,
  guest_name text,
  party_size integer,
  sequence bigint,
  status public.ticket_status,
  joined_at timestamptz,
  departed_at timestamptz,
  table_label text,
  departure_reason text,
  queue_position bigint,
  estimated_wait_minutes bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with mine as (
    select t.*
    from public.tickets t
    where t.venue_id = target_venue
      and t.owner_id = auth.uid()
      and (
        t.status in ('waiting', 'called', 'approaching', 'arrived') or
        (t.status = 'seated' and t.departed_at is null)
      )
    order by t.joined_at desc
    limit 1
  )
  select
    mine.id,
    mine.venue_id,
    mine.guest_name,
    mine.party_size,
    mine.sequence,
    mine.status,
    mine.joined_at,
    mine.departed_at,
    mine.table_label,
    mine.departure_reason,
    case
      when mine.status in ('called', 'arrived', 'seated') then 0
      else 1 + (
        select count(*) from public.tickets ahead
        where ahead.venue_id = mine.venue_id
          and ahead.sequence < mine.sequence
          and ahead.status in ('waiting', 'approaching')
      )
    end as queue_position,
    case
      when mine.status in ('called', 'arrived', 'seated') then 0
      else (
        select count(*) from public.tickets ahead
        where ahead.venue_id = mine.venue_id
          and ahead.sequence < mine.sequence
          and ahead.status in ('waiting', 'approaching')
      ) * (select v.average_turnover_minutes from public.venues v where v.id = mine.venue_id)
    end as estimated_wait_minutes
  from mine;
$$;

revoke all on function public.auto_release_seated_ticket(uuid, text) from public, anon;
grant execute on function public.auto_release_seated_ticket(uuid, text) to authenticated;
