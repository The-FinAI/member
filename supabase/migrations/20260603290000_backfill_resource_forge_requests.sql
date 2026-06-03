-- ============================================================
-- Backfill forge_request rows for resources that were created via the OLD
-- raw-insert path (the member profile "What I can bring" editor before it was
-- routed through forge_resource). Those rows have no forge_request, so a
-- member's already-submitted hours/resources never appear in the officer's
-- mint/forge queue (ForgeQueue reads forge_request where status='submitted').
--
-- Mirrors the phase-1 rebuild's E2 step, for any resource still lacking a
-- forge_request: one 'resource'/'create' request per resource, status carried
-- from approval_status so PENDING ones surface for review (approved/rejected
-- ones just record provenance). submitted_by = the holder. Idempotent.
-- ============================================================

insert into forge_request
  (target_type, action, target_id, payload, submitted_by, status, created_at)
select 'resource', 'create', r.id,
       jsonb_build_object('name', r.name, 'scope', r.scope,
                          'holder_member_id', r.holder_member_id,
                          'monthly_quota', r.monthly_quota),
       r.holder_member_id,
       case r.approval_status when 'approved' then 'approved'
                              when 'rejected' then 'rejected'
                              else 'submitted' end,
       coalesce(r.created_at, now())
from resource r
where r.forge_request_id is null
  and not exists (
    select 1 from forge_request fr
     where fr.target_type = 'resource' and fr.target_id = r.id
  );

update resource r
   set forge_request_id = fr.id
  from forge_request fr
 where fr.target_type = 'resource' and fr.target_id = r.id
   and r.forge_request_id is null;

notify pgrst, 'reload schema';
