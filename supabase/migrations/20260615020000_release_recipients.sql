-- =====================================================================
-- Staged release flow: announce a release to a small PREVIEW group first
-- (reviewers look it over), then to EVERYONE. release_recipients() returns the
-- email list for an audience; the `announce-release` edge function sends to it.
--
-- Security: the gate (manage_members) is in the WHERE clause, so a caller
-- without that capability gets an EMPTY list and no mail goes out — the same
-- can't-be-abused pattern as notify-writing-laggards / writing_laggards.
--
-- The preview group is whoever is flagged member.is_release_reviewer (set it for
-- Yuechen and Zhuoran). Idempotent.
-- =====================================================================

begin;

alter table member add column if not exists is_release_reviewer boolean not null default false;

create or replace function release_recipients(p_audience text)
returns table (member_id uuid, full_name text, email text)
language sql stable security definer set search_path = public as $$
  select m.id, m.full_name, m.email
  from member m
  where m.email is not null and m.email <> ''
    and m.archived_at is null
    and has_capability('manage_members')
    and (
      (p_audience = 'preview' and m.is_release_reviewer)
      or (p_audience = 'all')
    )
  order by m.is_release_reviewer desc, m.full_name;
$$;
grant execute on function release_recipients(text) to authenticated;

notify pgrst, 'reload schema';

commit;
