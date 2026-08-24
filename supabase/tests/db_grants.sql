-- After GoTrue booted (owns schema auth) and the prod dump is loaded:
-- Supabase-isms PostgREST needs on vanilla postgres.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
end $$;
create or replace function auth.uid() returns uuid
language sql stable as $$
  select ((nullif(current_setting('request.jwt.claims', true), '')::jsonb)->>'sub')::uuid
$$;
grant usage on schema public to anon, authenticated, service_role;
grant select on all tables in schema public to anon, authenticated;
grant execute on all functions in schema public to anon, authenticated;
grant usage on all sequences in schema public to authenticated;
