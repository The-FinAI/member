-- ============================================================
-- Backfill nominal STR for leader (first-author) seats taken BEFORE leader hours
-- started minting. For each leader work_commitment with nominal_str = 0:
--   * if it has no hours recorded (the hours field used to be hidden), set the
--     standard first-author writing hours (default 20);
--   * value those hours at the first-author writing rate.
-- This grows each affected project's nominal pool. Idempotent (only touches 0s).
-- ============================================================

update work_commitment w
   set monthly_amount = case when coalesce(w.monthly_amount, 0) = 0
                             then stater_policy_int('default_first_author_writing_hours', 20)
                             else w.monthly_amount end,
       nominal_str = coalesce(stater_policy_int('first_author_writing_rate',
                              stater_policy_int('paper_writing_rate', 10)), 10)
                     * (case when coalesce(w.monthly_amount, 0) = 0
                             then stater_policy_int('default_first_author_writing_hours', 20)
                             else w.monthly_amount end)
  from project_slot s
 where s.id = w.slot_id
   and s.slot_kind = 'leader'
   and coalesce(w.nominal_str, 0) = 0;

notify pgrst, 'reload schema';
