-- ============================================================
-- Reverse of forge_claim: a working-group officer (or admin) can RELEASE a
-- project their group claimed — detaching it (org_unit_id → null) so it returns
-- to the unclaimed pool. Fixes "can not cancel the project claim" (#4).
-- ============================================================

create or replace function release_claim(p_project uuid)
returns void language plpgsql security definer set search_path = public as $$
declare wg uuid; submitter uuid;
begin
  select org_unit_id into wg from project where id = p_project;
  if not exists (select 1 from project where id = p_project) then
    raise exception 'no such project';
  end if;
  if wg is null then return; end if;  -- already unclaimed
  if not (is_unit_officer(wg) or has_capability('edit_any_project') or has_capability('manage_stater')) then
    raise exception 'only a leader of this project''s working group can release the claim';
  end if;

  update project set org_unit_id = null where id = p_project;

  submitter := current_member_id();
  insert into forge_request (target_type, action, target_id, payload, submitted_by,
                             status, reviewed_by, review_note, settled_at)
  values ('claim', 'update', p_project,
          jsonb_build_object('project_id', p_project, 'wg_unit', null, 'released_from', wg),
          submitter, 'approved', submitter, 'claim released', now());
end $$;
grant execute on function release_claim(uuid) to authenticated;

notify pgrst, 'reload schema';
