-- =====================================================================
-- Issue #44/#41: a chapter officer should be able to edit ANY registered member
-- in their chapter (not just unclaimed cards). can_edit_member gated skills &
-- hours on self · manages_card · manage_members — which blocked officers from
-- editing claimed members / other officers in their own chapter.
--
-- Add is_unit_officer_of(member) (= caller is an officer of the member's home
-- chapter) to both the edit gate and the "apply directly vs queue for review"
-- check, so officers edit their whole roster directly while a plain member's
-- self-edit still goes to review (#40 B, model A). Idempotent.
-- =====================================================================

begin;

create or replace function can_edit_member(p_member uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_member = current_member_id()
      or manages_card(p_member)
      or is_unit_officer_of(p_member)
      or has_capability('manage_members');
$$;
grant execute on function can_edit_member(uuid) to authenticated;

-- same broadened "officer" notion for the review-or-apply decision
create or replace function member_change_submit(p_member uuid, p_kind text, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare is_officer boolean;
begin
  if p_kind not in ('skill', 'hours') then raise exception 'bad kind'; end if;
  is_officer := manages_card(p_member) or is_unit_officer_of(p_member) or has_capability('manage_members');

  if is_officer then
    if p_kind = 'skill' then
      perform person_skill_set((p_payload->>'skill_id')::uuid, nullif(p_payload->>'level', ''), p_member);
    else
      perform person_set_capacity((p_payload->>'hours')::int, p_member);
    end if;
    return jsonb_build_object('applied', true);
  end if;

  if not exists (select 1 from member where id = p_member and auth_user_id = auth.uid()) then
    raise exception 'not allowed to edit this card';
  end if;
  if p_kind = 'skill' then
    delete from member_change_request
      where member_id = p_member and kind = 'skill' and status = 'pending'
        and payload->>'skill_id' = p_payload->>'skill_id';
  else
    delete from member_change_request where member_id = p_member and kind = 'hours' and status = 'pending';
  end if;
  insert into member_change_request (member_id, kind, payload, requested_by)
  values (p_member, p_kind, p_payload, p_member);
  return jsonb_build_object('applied', false, 'pending', true);
end $$;
grant execute on function member_change_submit(uuid, text, jsonb) to authenticated;

notify pgrst, 'reload schema';

commit;
