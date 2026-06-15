-- =====================================================================
-- Issue #34 — close the create→undo rule's three gaps: a person card, a
-- project, and a need could be created but never removed. Adds:
--   * member.archived_at / project.archived_at + member_archive / project_archive
--     (soft-delete: hidden from the roster/ledger, history kept, reversible)
--   * slot_close — cancel an UNFILLED need (filled ones must be emptied first)
-- All authorised exactly like the matching create/edit path. Idempotent.
-- =====================================================================

begin;

alter table member  add column if not exists archived_at timestamptz;
alter table project add column if not exists archived_at timestamptz;

-- ---------- archive / unarchive a person card ----------
create or replace function member_archive(p_member uuid, p_archived boolean default true)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (manages_card(p_member) or has_capability('manage_members')) then
    raise exception 'not allowed to archive this person';
  end if;
  update member set archived_at = case when p_archived then now() else null end where id = p_member;
end $$;
grant execute on function member_archive(uuid, boolean) to authenticated;

-- ---------- archive / unarchive a project ----------
create or replace function project_archive(p_project uuid, p_archived boolean default true)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (can_edit_project(p_project) or has_capability('edit_any_project')) then
    raise exception 'not allowed to archive this project';
  end if;
  update project set archived_at = case when p_archived then now() else null end where id = p_project;
end $$;
grant execute on function project_archive(uuid, boolean) to authenticated;

-- ---------- close (cancel) an unfilled need ----------
create or replace function slot_close(p_slot uuid)
returns void language plpgsql security definer set search_path = public as $$
declare s project_slot; filled int;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  if not (can_edit_project(s.project_id) or has_capability('edit_any_project')) then
    raise exception 'not allowed to change this need';
  end if;
  select count(distinct member_id) into filled from work_commitment where slot_id = p_slot;
  if filled > 0 then raise exception 'this need has people on it — remove them first'; end if;
  update project_slot set status = 'cancelled' where id = p_slot;
end $$;
grant execute on function slot_close(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
