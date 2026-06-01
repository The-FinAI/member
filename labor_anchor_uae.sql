-- ============================================================
-- Re-calibrate the USD→STR anchor to a real UAE post-doc wage.
--
-- The v2 economy prices every resource in USD, then mints
--   STR = USD × str_per_usd.
-- The anchor is pinned to a reference human labour hour so that
-- compute / API / funding price on the same scale as people's time.
--
-- Previously that reference was a placeholder $50/hour.  We now peg it
-- to a UAE (MBZUAI) post-doctoral salary, which is tax-free:
--   * mid-band gross  ≈ $80,000 / year
--   * working time     = 1,920 h / year  (40 h/week × 48 weeks,
--                        i.e. after ~4 weeks UAE annual leave + holidays)
--   ⇒ usd_per_labor_hour = 80000 / 1920 ≈ $41.67 / hour
--
-- We KEEP the invariant  1 labour-hour = 10 STR  (= paper_writing_rate),
-- so the human-time scale and every already-minted balance are unchanged.
-- That fixes the dollar price of STR:
--   str_per_usd = 10 / 41.67 = 0.24
--
-- The anchor is one-directional today (value → STR, no redemption back
-- to USD); a two-way STR ⇄ USD peg may follow later.
-- Idempotent: safe to re-run.
-- ============================================================

update stater_policy
   set value = 41.67,
       description = 'Reference USD value of one labour hour — UAE post-doc wage (~$80k/yr ÷ 1,920 h). Anchors USD→STR so human time, compute and funding share one scale.'
 where key = 'usd_per_labor_hour';

update stater_policy
   set value = 0.24,
       description = 'STR minted per US dollar of resource value. Calibrated to a UAE post-doc hour: $41.67 × 0.24 = 10 STR = paper_writing_rate. One-way today; STR is not yet redeemable to USD.'
 where key = 'str_per_usd';

-- keep the Labor resource type's per-hour USD in step with the anchor
-- (so labour offered as a resource still mints 41.67 × 0.24 = 10 STR/hour)
update resource_type
   set usd_per_unit = 41.67
 where name = 'Labor' and valuation_method = 'flat';

notify pgrst, 'reload schema';
