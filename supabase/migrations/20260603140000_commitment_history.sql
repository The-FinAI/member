-- ============================================================
-- Project history was out of step with nominal STR.
--
-- The nominal pool on a project = Σ work_commitment.nominal_str. But:
--   * work_seat never wrote a project_event when it minted nominal STR, so
--     seatings left no history trail; and
--   * the Phase-1 rebuild migrated the nominal numbers into work_commitment
--     without generating the matching history events.
-- So a project could show a nominal pool with an empty / mismatched history.
--
-- Fix: (1) a trigger logs a project_event whenever a work_commitment is
-- created or its amount/nominal changes; (2) backfill one event per existing
-- work_commitment. Both stamp meta.work_commitment_id so they're idempotent and
-- never double-log. Now history reconciles with the nominal pool.
-- ============================================================

-- (1) going forward: log every commitment to the project history
create or replace function work_commitment_log_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  if tg_op = 'UPDATE'
     and new.nominal_str is not distinct from old.nominal_str
     and new.monthly_amount is not distinct from old.monthly_amount then
    return new;  -- nothing economic changed
  end if;
  select full_name into nm from member where id = new.member_id;
  insert into project_event (project_id, actor_member_id, event_type, summary, meta)
  values (new.project_id, new.member_id, 'stake_committed',
          coalesce(nm, 'A member') || ' · ' || new.monthly_amount
            || ' (' || new.year_month || ') → ' || new.nominal_str || ' nominal STR',
          jsonb_build_object('work_commitment_id', new.id,
                             'year_month', new.year_month,
                             'nominal_str', new.nominal_str));
  return new;
end $$;

drop trigger if exists work_commitment_log_event_t on work_commitment;
create trigger work_commitment_log_event_t
  after insert or update on work_commitment
  for each row execute function work_commitment_log_event();

-- (2) backfill history for commitments that pre-date the trigger
insert into project_event (project_id, actor_member_id, event_type, summary, meta, created_at)
select wc.project_id, wc.member_id, 'stake_committed',
       coalesce(m.full_name, 'A member') || ' · ' || wc.monthly_amount
         || ' (' || wc.year_month || ') → ' || wc.nominal_str || ' nominal STR',
       jsonb_build_object('work_commitment_id', wc.id,
                          'year_month', wc.year_month,
                          'nominal_str', wc.nominal_str),
       wc.created_at
from work_commitment wc
left join member m on m.id = wc.member_id
where not exists (
  select 1 from project_event e
   where e.project_id = wc.project_id
     and e.meta->>'work_commitment_id' = wc.id::text
);

notify pgrst, 'reload schema';
