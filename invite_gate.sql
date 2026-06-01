-- Invite-only login gate. Lets the (pre-auth) login page check that an email
-- belongs to a pre-created member row BEFORE requesting a magic link, so a
-- non-invited email never creates a Supabase auth user / triggers a signup
-- email. SECURITY DEFINER so it can read past RLS; returns only a boolean.

begin;

create or replace function is_email_invited(p_email text)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from member
     where lower(email) = lower(btrim(coalesce(p_email, '')))
  );
$$;

-- callable before sign-in (anon) and after (authenticated)
grant execute on function is_email_invited(text) to anon, authenticated;

commit;
