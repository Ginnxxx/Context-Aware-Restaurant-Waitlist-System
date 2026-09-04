-- QueueLess milestone 4: context transitions and secure QR arrival verification.
-- Run after 202608100001_initial_schema.sql.

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
    'outer_geofence_exited'
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
  if selected_ticket.status not in ('waiting', 'approaching', 'called') then
    raise exception 'Ticket is not active';
  end if;

  -- Ignore duplicate transitions reported within 60 seconds.
  select * into new_event
  from public.context_events
  where ticket_id = target_ticket
    and event_type = target_event_type
    and created_at > now() - interval '60 seconds'
  order by created_at desc
  limit 1;

  if found then return new_event; end if;

  insert into public.context_events (
    ticket_id, owner_id, event_type, distance_band
  ) values (
    target_ticket, auth.uid(), target_event_type, target_distance_band
  ) returning * into new_event;

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
  end if;

  return new_event;
end;
$$;

create or replace function public.verify_ticket_qr(
  target_ticket uuid,
  supplied_nonce uuid
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
  for update;

  if not found then raise exception 'Ticket not found'; end if;
  if not public.is_venue_staff(selected_ticket.venue_id) then
    raise exception 'Staff permission required';
  end if;
  if selected_ticket.qr_nonce <> supplied_nonce then
    raise exception 'Invalid QR ticket';
  end if;

  if selected_ticket.status = 'arrived' then return selected_ticket; end if;
  if selected_ticket.status <> 'called' then
    raise exception 'The party must be called before check-in';
  end if;

  update public.tickets
  set status = 'arrived', arrived_at = now(), updated_at = now()
  where id = target_ticket
  returning * into selected_ticket;

  return selected_ticket;
end;
$$;

revoke all on function public.record_context_event(uuid, text, text) from public, anon;
revoke all on function public.verify_ticket_qr(uuid, uuid) from public, anon;
grant execute on function public.record_context_event(uuid, text, text) to authenticated;
grant execute on function public.verify_ticket_qr(uuid, uuid) to authenticated;

