-- QueueLess milestone 11: Make target_venue optional in my_active_ticket_snapshot
-- Run after 202608310007_multi_venue.sql.

drop function if exists public.my_active_ticket_snapshot(uuid);
create or replace function public.my_active_ticket_snapshot(target_venue uuid default null)
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
    where t.owner_id = auth.uid()
      and (target_venue is null or t.venue_id = target_venue)
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
      ) * (select coalesce(v.average_turnover_minutes, 5) from public.venues v where v.id = mine.venue_id)
    end as estimated_wait_minutes
  from mine;
$$;

revoke all on function public.my_active_ticket_snapshot from public, anon;
grant execute on function public.my_active_ticket_snapshot to authenticated;
