-- Minimal Supabase-isms so a prod schema dump loads into vanilla postgres:17.
-- (The dump covers public + supabase_migrations only; auth lives here.)
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;

create schema auth;
create table auth.users (
  id uuid primary key,
  email text,
  created_at timestamptz default now()
);
create or replace function auth.uid() returns uuid
language sql stable as $$
  select ((nullif(current_setting('request.jwt.claims', true), '')::jsonb)->>'sub')::uuid
$$;
