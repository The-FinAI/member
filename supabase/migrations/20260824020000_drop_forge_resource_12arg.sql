-- Smoke catch #2: two live forge_resource overloads (12-arg superseded by the
-- 13-arg p_details version in 20260603330000). Positional calls are ambiguous
-- and PostgREST named calls can 300. Drop the stale one.
drop function if exists forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric, jsonb, guild_level, uuid, uuid);

notify pgrst, 'reload schema';
