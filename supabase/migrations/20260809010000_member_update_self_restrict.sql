-- F1 (Critical): member_update_self RLS policy was over-permissive.
-- The broad UPDATE policy let any member update any column on their own row via
-- direct PostgREST (auth_user_id, email, kind, status, archived_at, etc.).
--
-- Fix: replace the table-level UPDATE grant with column-level grants for the two
-- fields a member legitimately self-edits (affiliation, bio). All other columns
-- require the manage_members capability (handled by the existing member_manage policy).
-- Security-definer RPCs are unaffected — they execute as the function owner.

-- Step 1: revoke the broad column-unrestricted UPDATE permission.
revoke update on member from authenticated;

-- Step 2: grant UPDATE only on the safe profile fields (affiliation, bio, links).
-- links (jsonb) holds scholar/hf/github/homepage profile URLs — self-editable.
grant update (affiliation, bio, links) on member to authenticated;

-- Step 3: the RLS policy itself remains correct (auth_user_id = auth.uid()) — no change needed.
-- The combination of column-level grants + RLS ensures self-edits are both
-- row-scoped (own row only) and column-scoped (safe fields only).
