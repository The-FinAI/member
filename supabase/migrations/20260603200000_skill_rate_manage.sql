-- Let guild stewards (not just manage_stater) edit the per-skill labor rate,
-- so the Skill rates editor in the Guild console is usable. Idempotent.
drop policy if exists manage_stater_rate on stater_skill_rate;
create policy manage_stater_rate on stater_skill_rate for all to authenticated
  using (has_capability('manage_stater') or has_capability('manage_guild'))
  with check (has_capability('manage_stater') or has_capability('manage_guild'));
grant insert, update, delete on stater_skill_rate to authenticated;
