-- ============================================================
-- Point settlement at the Phase-1 nominal model (+ milestones).
--
-- approve_settlement() already computes the payout as
--   target = stater_project_nominal_pool(project) × stater_milestone_mult(project)
-- but both helpers still read the DEPRECATED stater_project_stake_commitment /
-- stater_commitment_period tables — so after the Phase-1 rebuild settlement
-- ignored all work_commitment nominal and under-paid. Redefine the two helpers
-- against the live model; approve_settlement is untouched.
--
--   nominal pool = Σ work_commitment.nominal_str  +  Σ verified milestone nominal
--   multiplier   = min( finish_bonus_ratio + Σ verified milestone bonus , cap )
-- ============================================================

create or replace function stater_project_nominal_pool(p uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select sum(nominal_str) from work_commitment where project_id = p), 0)
       + coalesce((select sum(nominal_value) from project_milestone
                   where project_id = p and status = 'verified'), 0);
$$;

create or replace function stater_milestone_mult(p uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select least(
    stater_policy_num('finish_bonus_ratio', 1.0)
    + coalesce((select sum(multiplier_bonus) from project_milestone
                where project_id = p and status = 'verified'), 0),
    stater_policy_num('milestone_multiplier_cap', 3.0));
$$;

notify pgrst, 'reload schema';
