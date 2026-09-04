-- QueueLess initial schema for Supabase Free.
-- Run this migration in a fresh project with anonymous sign-ins enabled.

create extension if not exists pgcrypto;

create type public.ticket_status as enum (
  'waiting',
  'called',
  'approaching',
  'arrived',
  'seated',
  'cancelled',
  'no_show'
);

create type public.staff_role as enum ('manager', 'host');

create table public.venues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  queue_open boolean not null default true,
  average_turnover_minutes integer not null default 5 check (average_turnover_minutes between 1 and 120),
  grace_period_minutes integer not null default 10 check (grace_period_minutes between 1 and 60),
  outer_geofence_meters integer not null default 800 check (outer_geofence_meters between 100 and 5000),
  arrival_geofence_meters integer not null default 100 check (arrival_geofence_meters between 25 and 500),
  next_sequence bigint not null default 1,
  created_at timestamptz not null default now()
);

create table public.venue_staff (
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.staff_role not null default 'host',
  created_at timestamptz not null default now(),
  primary key (venue_id, user_id)
);

create table public.tickets (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  guest_name text not null check (char_length(guest_name) between 1 and 60),
  party_size integer not null check (party_size between 1 and 12),
  sequence bigint not null,
  status public.ticket_status not null default 'waiting',
  qr_nonce uuid not null default gen_random_uuid(),
  joined_at timestamptz not null default now(),
  called_at timestamptz,
  approaching_at timestamptz,
  arrived_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (venue_id, sequence)
);

create unique index one_active_ticket_per_user_per_venue
  on public.tickets (venue_id, owner_id)
  where status in ('waiting', 'called', 'approaching', 'arrived');

create index tickets_live_queue_idx
  on public.tickets (venue_id, status, sequence);

create table public.context_events (
  id bigint generated always as identity primary key,
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in (
    'leave_now_recommended',
    'outer_geofence_entered',
    'arrival_geofence_entered',
    'outer_geofence_exited'
  )),
  distance_band text check (distance_band in ('far', 'approaching', 'near')),
  created_at timestamptz not null default now()
);

create table public.device_installations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  fcm_token text not null unique,
  updated_at timestamptz not null default now()
);

create table public.notification_jobs (
  id bigint generated always as identity primary key,
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  kind text not null check (kind in ('table_ready', 'grace_warning')),
  state text not null default 'pending' check (state in ('pending', 'sending', 'sent', 'failed')),
  attempts integer not null default 0,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  error_message text
);

create or replace function public.is_venue_staff(target_venue uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.venue_staff
    where venue_id = target_venue and user_id = auth.uid()
  );
$$;

create or replace function public.join_queue(
  target_venue uuid,
  customer_name text,
  customer_party_size integer
)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_venue public.venues;
  new_ticket public.tickets;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if char_length(trim(customer_name)) not between 1 and 60 then
    raise exception 'Guest name must contain 1 to 60 characters';
  end if;

  if customer_party_size not between 1 and 12 then
    raise exception 'Party size must be between 1 and 12';
  end if;

  select * into selected_venue
  from public.venues
  where id = target_venue
  for update;

  if not found then raise exception 'Venue not found'; end if;
  if not selected_venue.queue_open then raise exception 'Queue is paused'; end if;

  if exists (
    select 1 from public.tickets
    where venue_id = target_venue
      and owner_id = auth.uid()
      and status in ('waiting', 'called', 'approaching', 'arrived')
  ) then
    raise exception 'You already have an active ticket for this venue';
  end if;

  insert into public.tickets (
    venue_id, owner_id, guest_name, party_size, sequence
  ) values (
    target_venue, auth.uid(), trim(customer_name), customer_party_size,
    selected_venue.next_sequence
  ) returning * into new_ticket;

  update public.venues
  set next_sequence = next_sequence + 1
  where id = target_venue;

  return new_ticket;
end;
$$;

create or replace function public.call_next_party(target_venue uuid)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_ticket public.tickets;
begin
  if not public.is_venue_staff(target_venue) then
    raise exception 'Staff permission required';
  end if;

  select * into selected_ticket
  from public.tickets
  where venue_id = target_venue and status in ('waiting', 'approaching')
  order by sequence
  for update skip locked
  limit 1;

  if not found then raise exception 'No waiting parties'; end if;

  update public.tickets
  set status = 'called', called_at = now(), updated_at = now()
  where id = selected_ticket.id
  returning * into selected_ticket;

  insert into public.notification_jobs (ticket_id, kind)
  values (selected_ticket.id, 'table_ready');

  return selected_ticket;
end;
$$;

create or replace function public.cancel_my_ticket(target_ticket uuid)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_ticket public.tickets;
begin
  update public.tickets
  set status = 'cancelled', completed_at = now(), updated_at = now()
  where id = target_ticket
    and owner_id = auth.uid()
    and status in ('waiting', 'called', 'approaching')
  returning * into selected_ticket;

  if not found then raise exception 'Active ticket not found'; end if;
  return selected_ticket;
end;
$$;

create or replace function public.my_active_ticket_snapshot(target_venue uuid)
returns table (
  id uuid,
  venue_id uuid,
  guest_name text,
  party_size integer,
  sequence bigint,
  status public.ticket_status,
  joined_at timestamptz,
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
      and t.status in ('waiting', 'called', 'approaching', 'arrived')
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
    case
      when mine.status in ('called', 'arrived') then 0
      else 1 + (
        select count(*) from public.tickets ahead
        where ahead.venue_id = mine.venue_id
          and ahead.sequence < mine.sequence
          and ahead.status in ('waiting', 'approaching')
      )
    end as queue_position,
    case
      when mine.status in ('called', 'arrived') then 0
      else (
        select count(*) from public.tickets ahead
        where ahead.venue_id = mine.venue_id
          and ahead.sequence < mine.sequence
          and ahead.status in ('waiting', 'approaching')
      ) * (select average_turnover_minutes from public.venues where venues.id = mine.venue_id)
    end as estimated_wait_minutes
  from mine;
$$;

create or replace function public.staff_transition_ticket(
  target_ticket uuid,
  next_status public.ticket_status
)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_ticket public.tickets;
begin
  select * into selected_ticket from public.tickets where id = target_ticket for update;
  if not found then raise exception 'Ticket not found'; end if;
  if not public.is_venue_staff(selected_ticket.venue_id) then raise exception 'Staff permission required'; end if;

  if not (
    (selected_ticket.status = 'called' and next_status in ('arrived', 'no_show')) or
    (selected_ticket.status = 'approaching' and next_status in ('called', 'cancelled')) or
    (selected_ticket.status = 'arrived' and next_status = 'seated') or
    (selected_ticket.status = 'waiting' and next_status = 'cancelled')
  ) then
    raise exception 'Invalid ticket transition from % to %', selected_ticket.status, next_status;
  end if;

  update public.tickets set
    status = next_status,
    arrived_at = case when next_status = 'arrived' then now() else arrived_at end,
    completed_at = case when next_status in ('seated', 'cancelled', 'no_show') then now() else completed_at end,
    updated_at = now()
  where id = target_ticket
  returning * into selected_ticket;

  return selected_ticket;
end;
$$;

alter table public.venues enable row level security;
alter table public.venue_staff enable row level security;
alter table public.tickets enable row level security;
alter table public.context_events enable row level security;
alter table public.device_installations enable row level security;
alter table public.notification_jobs enable row level security;

create policy "authenticated users can view venues"
  on public.venues for select to authenticated using (true);

create policy "staff can update their venue"
  on public.venues for update to authenticated
  using (public.is_venue_staff(id)) with check (public.is_venue_staff(id));

create policy "staff can view own memberships"
  on public.venue_staff for select to authenticated
  using (user_id = auth.uid());

create policy "customers view own tickets and staff view venue tickets"
  on public.tickets for select to authenticated
  using (owner_id = auth.uid() or public.is_venue_staff(venue_id));

create policy "customers record own context events"
  on public.context_events for insert to authenticated
  with check (
    owner_id = auth.uid() and exists (
      select 1 from public.tickets
      where tickets.id = ticket_id and tickets.owner_id = auth.uid()
    )
  );

create policy "customers view own context events and staff view venue events"
  on public.context_events for select to authenticated
  using (
    owner_id = auth.uid() or exists (
      select 1 from public.tickets
      where tickets.id = ticket_id and public.is_venue_staff(tickets.venue_id)
    )
  );

create policy "customers manage own installations"
  on public.device_installations for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "staff view notification jobs for their venue"
  on public.notification_jobs for select to authenticated
  using (exists (
    select 1 from public.tickets
    where tickets.id = ticket_id and public.is_venue_staff(tickets.venue_id)
  ));

revoke all on function public.join_queue(uuid, text, integer) from public, anon;
revoke all on function public.call_next_party(uuid) from public, anon;
revoke all on function public.cancel_my_ticket(uuid) from public, anon;
revoke all on function public.my_active_ticket_snapshot(uuid) from public, anon;
revoke all on function public.staff_transition_ticket(uuid, public.ticket_status) from public, anon;
grant execute on function public.join_queue(uuid, text, integer) to authenticated;
grant execute on function public.call_next_party(uuid) to authenticated;
grant execute on function public.cancel_my_ticket(uuid) to authenticated;
grant execute on function public.my_active_ticket_snapshot(uuid) to authenticated;
grant execute on function public.staff_transition_ticket(uuid, public.ticket_status) to authenticated;
revoke all on table public.notification_jobs from anon, authenticated;

-- Enable these tables in Realtime. Safe to rerun manually if already added.
alter publication supabase_realtime add table public.venues;
alter publication supabase_realtime add table public.tickets;
