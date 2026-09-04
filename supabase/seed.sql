-- Development seed. Replace the coordinates/address before a real demonstration.
insert into public.venues (
  id, name, address, latitude, longitude,
  average_turnover_minutes, grace_period_minutes, seat_capacity,
  outer_geofence_meters, arrival_geofence_meters
) values (
  '00000000-0000-0000-0000-000000000001',
  'UIT',
  'University of Information Technology',
  16.85585333977064,
  96.13527117698501,
  5,
  10,
  40,
  800,
  100
) on conflict (id) do update set
  name = excluded.name,
  address = excluded.address,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  seat_capacity = excluded.seat_capacity;

-- After creating a staff user in Authentication, run:
-- insert into public.venue_staff (venue_id, user_id, role)
-- values ('00000000-0000-0000-0000-000000000001', '<AUTH USER UUID>', 'manager');
