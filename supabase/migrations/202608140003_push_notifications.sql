-- QueueLess milestone 6: safe FCM device registration.
-- Run after 202608140002_context_and_qr.sql.

create or replace function public.register_device_installation(
  target_platform text,
  target_fcm_token text
)
returns public.device_installations
language plpgsql
security definer
set search_path = public
as $$
declare
  installation public.device_installations;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target_platform not in ('android', 'ios', 'web') then
    raise exception 'Unsupported platform';
  end if;
  if char_length(trim(target_fcm_token)) not between 20 and 4096 then
    raise exception 'Invalid FCM token';
  end if;

  insert into public.device_installations (owner_id, platform, fcm_token)
  values (auth.uid(), target_platform, trim(target_fcm_token))
  on conflict (fcm_token) do update set
    owner_id = excluded.owner_id,
    platform = excluded.platform,
    updated_at = now()
  returning * into installation;

  return installation;
end;
$$;

revoke all on function public.register_device_installation(text, text)
  from public, anon;
grant execute on function public.register_device_installation(text, text)
  to authenticated;
