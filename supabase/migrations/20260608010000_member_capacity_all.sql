-- ============================================================
-- GitHub #10 / #14 — show "available time" as remaining / total per month
-- on the roster too (not just the member card). One batch call returns
-- total + free for every member, so /people can render x/y without N+1.
--   total = monthly_hours (fallback to the member's Labor resource cap)
--   free  = total minus hours already committed this month  (NULL = undeclared)
-- ============================================================
create or replace function member_capacity_all(p_ym text)
returns table (member_id uuid, total numeric, free numeric)
language sql stable security definer set search_path = public as $$
  select m.id,
         coalesce(m.monthly_hours, member_labor_cap(m.id)) as total,
         member_free_hours(m.id, p_ym)                     as free
    from member m;
$$;
grant execute on function member_capacity_all(text) to authenticated;

notify pgrst, 'reload schema';
