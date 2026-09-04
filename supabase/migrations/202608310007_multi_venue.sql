-- QueueLess milestone 10: Multi-venue management and dynamic coordinates update.
-- Run after 202608240006_customer_delay.sql.

-- Enable all authenticated users to view all venues
create policy "Venues are viewable by everyone"
  on public.venues for select
  to public, anon, authenticated
  using (true);

-- Function for staff to create a new venue/branch
create or replace function public.create_venue(
  venue_name text,
  venue_address text default '',
  venue_lat double precision default 16.85585,
  venue_lng double precision default 96.13527,
  turnover_mins integer default 5,
  outer_meters integer default 800,
  arrival_meters integer default 100,
  capacity integer default 40
)
returns public.venues
language plpgsql
security definer
set search_path = public
as $$
declare
  created_venue public.venues;
begin
  insert into public.venues (
    name,
    address,
    latitude,
    longitude,
    average_turnover_minutes,
    outer_geofence_meters,
    arrival_geofence_meters,
    seat_capacity,
    queue_open
  ) values (
    venue_name,
    venue_address,
    venue_lat,
    venue_lng,
    turnover_mins,
    outer_meters,
    arrival_meters,
    capacity,
    true
  )
  returning * into created_venue;

  -- Automatically assign the creator as a manager of the new venue
  insert into public.venue_staff (venue_id, user_id, role)
  values (created_venue.id, auth.uid(), 'manager')
  on conflict do nothing;

  return created_venue;
end;
$$;

-- Function for staff to update any venue settings including coordinates
create or replace function public.update_venue_settings_v2(
  target_venue uuid,
  venue_name text,
  venue_address text,
  venue_lat double precision,
  venue_lng double precision,
  turnover_mins integer,
  outer_meters integer,
  arrival_meters integer,
  capacity integer
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
    name = venue_name,
    address = venue_address,
    latitude = venue_lat,
    longitude = venue_lng,
    average_turnover_minutes = turnover_mins,
    outer_geofence_meters = outer_meters,
    arrival_geofence_meters = arrival_meters,
    seat_capacity = capacity
  where id = target_venue
  returning * into updated_venue;

  if not found then
    raise exception 'Venue not found: %', target_venue;
  end if;

  return updated_venue;
end;
$$;

revoke all on function public.create_venue from public, anon;
grant execute on function public.create_venue to authenticated;

revoke all on function public.update_venue_settings_v2 from public, anon;
grant execute on function public.update_venue_settings_v2 to authenticated;
