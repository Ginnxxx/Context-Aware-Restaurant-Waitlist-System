-- QueueLess milestone 9: adaptive customer delay reporting.
-- Run after 202608240005_auto_departure.sql.

alter table public.tickets
  add column if not exists delay_minutes integer not null default 0
  check (delay_minutes between 0 and 30);

-- Update context_events constraint to allow customer_delayed and seated_guest_departed
alter table public.context_events
  drop constraint if exists context_events_event_type_check;

alter table public.context_events
  add constraint context_events_event_type_check
  check (event_type in (
    'leave_now_recommended',
    'outer_geofence_entered',
    'arrival_geofence_entered',
    'outer_geofence_exited',
    'arrival_geofence_exited',
    'seated_guest_departed',
    'customer_delayed'
  ));

-- Allow customer to request delay extension (+5m increments up to 10m max)
create or replace function public.report_ticket_delay(
  target_ticket uuid,
  additional_minutes integer default 5
)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_ticket public.tickets;
  new_delay integer;
begin
  select * into selected_ticket
  from public.tickets
  where id = target_ticket and owner_id = auth.uid()
  for update;

  if not found then raise exception 'Ticket not found or unauthorized'; end if;
  if selected_ticket.status not in ('waiting', 'approaching', 'called') then
    raise exception 'Cannot report delay for inactive ticket';
  end if;

  new_delay := selected_ticket.delay_minutes + additional_minutes;
  if new_delay > 10 then
    raise exception 'Maximum delay extension is 10 minutes';
  end if;

  insert into public.context_events (
    ticket_id, owner_id, event_type, distance_band
  ) values (
    target_ticket, auth.uid(), 'customer_delayed', 'approaching'
  );

  update public.tickets set
    delay_minutes = new_delay,
    updated_at = now()
  where id = target_ticket
  returning * into selected_ticket;

  return selected_ticket;
end;
$$;

-- Drop and recreate my_active_ticket_snapshot to include delay_minutes and called_at
drop function if exists public.my_active_ticket_snapshot(uuid);
create or replace function public.my_active_ticket_snapshot(target_venue uuid)
returns table (
  id uuid,
  venue_id uuid,
  guest_name text,
  party_size integer,
  sequence bigint,
  status public.ticket_status,
  joined_at timestamptz,
  called_at timestamptz,
  departed_at timestamptz,
  table_label text,
  departure_reason text,
  delay_minutes integer,
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
    mine.called_at,
    mine.departed_at,
    mine.table_label,
    mine.departure_reason,
    mine.delay_minutes,
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

revoke all on function public.report_ticket_delay(uuid, integer) from public, anon;
grant execute on function public.report_ticket_delay(uuid, integer) to authenticated;
revoke all on function public.my_active_ticket_snapshot(uuid) from public, anon;
grant execute on function public.my_active_ticket_snapshot(uuid) to authenticated;
