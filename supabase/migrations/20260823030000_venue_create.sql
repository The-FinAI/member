-- Market: create a submission venue (the taxonomy admin surface is retired;
-- the market is the app). Signed-in under governance v0.3.
create or replace function venue_create(p_name text, p_kind text, p_deadline date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare vid uuid;
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'name required'; end if;
  if p_kind not in ('conference','journal','rolling') then
    raise exception 'kind must be conference|journal|rolling'; end if;
  if exists (select 1 from venue where lower(name) = lower(trim(p_name))) then
    raise exception 'venue already exists'; end if;
  insert into venue (name, kind, deadline, rank)
  values (trim(p_name), p_kind, p_deadline, coalesce((select max(rank) + 1 from venue), 1))
  returning id into vid;
  return vid;
end $$;
grant execute on function venue_create(text, text, date) to authenticated;

notify pgrst, 'reload schema';
