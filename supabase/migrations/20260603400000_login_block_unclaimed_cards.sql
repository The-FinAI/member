-- ============================================================
-- Phase 1 is officers-only: a pre-created member CARD (kind='card') must NOT be
-- able to log in until it is claimed. Tighten the invite gate so a login is
-- allowed only when the email belongs to a real member, or a card that has
-- already been bound to an auth user (i.e. claimed). An unclaimed card's email
-- is rejected at the login page.
-- ============================================================

create or replace function is_email_invited(p_email text)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from member
     where lower(email) = lower(btrim(coalesce(p_email, '')))
       and (kind <> 'card' or auth_user_id is not null)
  );
$$;
grant execute on function is_email_invited(text) to anon, authenticated;

notify pgrst, 'reload schema';
