-- QueueLess milestone: staff operations hardening.
-- Allow staff to transition tickets flexibly across active states (waiting -> called/arrived/cancelled, etc.)
-- Run after 202608310008_fix_active_ticket.sql.

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

  -- Validate valid staff transitions:
  -- waiting -> called, arrived, cancelled
  -- approaching -> called, arrived, cancelled
  -- called -> arrived, no_show, cancelled
  -- arrived -> seated, cancelled
  if not (
    (selected_ticket.status = 'called' and next_status in ('arrived', 'no_show', 'cancelled')) or
    (selected_ticket.status = 'approaching' and next_status in ('called', 'arrived', 'cancelled')) or
    (selected_ticket.status = 'waiting' and next_status in ('called', 'arrived', 'cancelled')) or
    (selected_ticket.status = 'arrived' and next_status in ('seated', 'cancelled'))
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
    called_at = case when next_status = 'called' then coalesce(selected_ticket.called_at, now()) else selected_ticket.called_at end,
    arrived_at = case when next_status = 'arrived' then coalesce(selected_ticket.arrived_at, now()) else selected_ticket.arrived_at end,
    completed_at = case
      when next_status in ('seated', 'cancelled', 'no_show') then now()
      else completed_at
    end,
    updated_at = now()
  where id = target_ticket
  returning * into selected_ticket;

  if next_status = 'called' then
    insert into public.notification_jobs (ticket_id, kind)
    values (selected_ticket.id, 'table_ready');
  end if;

  return selected_ticket;
end;
$$;

revoke all on function public.staff_transition_ticket(uuid, public.ticket_status, text) from public, anon;
grant execute on function public.staff_transition_ticket(uuid, public.ticket_status, text) to authenticated;
