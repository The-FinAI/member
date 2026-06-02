-- ============================================================
-- Let a card's manager edit that card's offerable catalog.
--
-- The base `manage_resource` policy only lets a member write their OWN
-- member-scoped resources (holder = current_member_id) or a manage_resources
-- steward write anything. Member-cards have no auth user of their own, so the
-- chapter officer (chair/secretary) who forged the card could not fill in the
-- card's "What I can bring" (monthly time + resources).
--
-- Extend the policy with `manages_card(holder_member_id)`, which is true only
-- for the chair/secretary of the card's home chapter (or a manage_members
-- admin) and only for members of kind='card'. The approval trigger still forces
-- officer-added resources to start 'pending', so a steward review is unchanged.
-- ============================================================

drop policy if exists manage_resource on resource;
create policy manage_resource on resource for all to authenticated
  using (
    (scope = 'member' and holder_member_id = current_member_id())
    or (scope = 'member' and holder_member_id is not null and manages_card(holder_member_id))
    or has_capability('manage_resources')
  )
  with check (
    (scope = 'member' and holder_member_id = current_member_id())
    or (scope = 'member' and holder_member_id is not null and manages_card(holder_member_id))
    or has_capability('manage_resources')
  );

notify pgrst, 'reload schema';
