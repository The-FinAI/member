-- Multi-user live sync for the market: publish the tables the page renders.
-- The client subscribes schema-wide and quietly refetches on any change, so
-- one member's edit appears on everyone's screen within a second.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

alter publication supabase_realtime add table
  project, project_slot, work_commitment, member, person_skill,
  resource, org_unit, venue;
