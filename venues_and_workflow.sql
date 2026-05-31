-- ============================================================
-- Venues (conferences / journals) with a target deadline, and a
-- controlled status-transition pipeline for projects.
-- Idempotent: safe to re-run.
-- ============================================================

-- ---------- VENUE taxonomy (admin-managed) ----------
create table if not exists venue (
  id         uuid primary key default gen_random_uuid(),
  name       text unique not null,
  kind       text not null default 'conference',  -- conference | journal | workshop | rolling | other
  url        text,
  deadline   date,           -- next submission deadline (single)
  notes      text,
  rank       int not null default 100,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

-- seed from the venues already used by projects
insert into venue (name, kind, rank) values
  ('NeurIPS', 'conference', 10),
  ('ICML',    'conference', 20),
  ('ICLR',    'conference', 30),
  ('ACL',     'conference', 40),
  ('EMNLP',   'conference', 50),
  ('AAAI',    'conference', 60),
  ('COLM',    'conference', 70),
  ('WWW',     'conference', 80),
  ('MM',      'conference', 90),
  ('ARR',     'rolling',    100),
  ('ACM Computing Survey', 'journal', 110),
  ('IPM',     'journal',    120)
on conflict (name) do nothing;

-- ---------- PROJECT: venue link + status pipeline memory ----------
alter table project add column if not exists venue_id uuid references venue(id);
alter table project add column if not exists held_from_status_id uuid references project_status(id);

-- backfill venue_id from the legacy free-text target_venue
update project p set venue_id = v.id
  from venue v
  where p.venue_id is null and p.target_venue is not null and p.target_venue = v.name;

-- ---------- CONTROLLED STATUS PIPELINE ----------
-- Allowed moves:
--   * forward / backward exactly one step along the rank-ordered pipeline
--     (Proposal → Data Collecting → Work in progress → Under review → Finished),
--   * Hold from any non-finished status (remembers where it paused),
--   * Resume from Hold back to the remembered status.
create or replace function transition_project_status(p uuid, target uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  cur uuid; cur_name text; cur_rank int;
  tgt_name text; tgt_rank int;
  hold_id uuid; held uuid; next_rank int; prev_rank int;
begin
  if not (manages_project(p) or has_capability('edit_any_project')) then
    raise exception 'not authorized to change status';
  end if;

  select status_id, held_from_status_id into cur, held from project where id = p;
  if target is null then raise exception 'no target status'; end if;
  if target = cur then return; end if;

  select name, rank into cur_name, cur_rank from project_status where id = cur;
  select name, rank into tgt_name, tgt_rank from project_status where id = target;
  if tgt_name is null then raise exception 'unknown status'; end if;

  select id into hold_id from project_status where name = 'Hold';

  -- pause → Hold (only from a live, non-finished state)
  if target = hold_id then
    if cur_name = 'Finished' then raise exception 'a finished project cannot be put on hold'; end if;
    update project set held_from_status_id = cur, status_id = target where id = p;
    return;
  end if;

  -- resume from Hold → back to the remembered status (or Proposal if none)
  if cur_name = 'Hold' then
    if target = coalesce(held, (select id from project_status where name = 'Proposal')) then
      update project set status_id = target, held_from_status_id = null where id = p;
      return;
    end if;
    raise exception 'resume to the status it was paused at before advancing';
  end if;

  -- normal pipeline: target must be the immediate next or previous rank (excluding Hold)
  select min(rank) into next_rank from project_status where rank > cur_rank and name <> 'Hold';
  select max(rank) into prev_rank from project_status where rank < cur_rank and name <> 'Hold';
  if tgt_rank = next_rank or tgt_rank = prev_rank then
    update project set status_id = target where id = p;
    return;
  end if;

  raise exception '% → % is not an allowed transition', cur_name, tgt_name;
end; $$;
grant execute on function transition_project_status(uuid, uuid) to authenticated;

-- ---------- richer project creation: venue + proposal, atomic ----------
-- Replace the 6-arg version with one that also wires a venue and drops the
-- proposal link in atomically (so a project always starts with its proposal).
drop function if exists create_project_with_leader_stake(text, uuid, uuid, text, text, integer);
create or replace function create_project_with_leader_stake(
  p_name text, p_type_id uuid, p_status_id uuid, p_venue text, p_summary text,
  p_stake integer default null, p_venue_id uuid default null, p_proposal_url text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; pid uuid; esc uuid; lstake integer; lrole uuid; vname text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  lstake := coalesce(p_stake, (select leader_stake from project_type where id = p_type_id),
                     stater_policy_int('leader_stake_normal', 50));
  vname := coalesce((select name from venue where id = p_venue_id), p_venue);
  insert into project (name, type_id, status_id, target_venue, venue_id, summary)
  values (p_name, p_type_id, p_status_id, vname, p_venue_id, p_summary) returning id into pid;
  esc := stater_project_acc(pid);  -- created by trigger
  perform stater_move(stater_member_acc(me), esc, lstake, 'stake', 'leader initiation stake', pid, null, null, me);
  select id into lrole from project_role where name = 'Leader' limit 1;
  insert into project_member (project_id, member_id, project_role_id) values (pid, me, lrole) on conflict do nothing;
  insert into stater_project_stake_commitment (project_id, member_id, commitment_type, token_amount, status, verified_by, verified_at)
  values (pid, me, 'leader_initiation', lstake, 'verified', me, now());
  if p_proposal_url is not null and length(trim(p_proposal_url)) > 0 then
    insert into project_link (project_id, kind, title, url, added_by)
    values (pid, 'proposal', 'Proposal', trim(p_proposal_url), me);
  end if;
  return pid;
end; $$;
grant execute on function create_project_with_leader_stake(text, uuid, uuid, text, text, integer, uuid, text) to authenticated;

-- ---------- RLS + grants for venue ----------
alter table venue enable row level security;
drop policy if exists read_venue on venue;
create policy read_venue on venue for select to authenticated using (true);
drop policy if exists manage_venue on venue;
create policy manage_venue on venue for all to authenticated
  using (has_capability('manage_taxonomy')) with check (has_capability('manage_taxonomy'));

grant select on venue to anon, authenticated;
grant insert, update, delete on venue to authenticated;

notify pgrst, 'reload schema';
