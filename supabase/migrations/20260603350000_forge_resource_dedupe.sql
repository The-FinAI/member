-- ============================================================
-- Successive migrations added params to forge_resource with `create or replace`,
-- which created NEW overloads (8, 9, 10, 12, 13 args) rather than replacing the
-- old ones. A call with fewer named args (e.g. forging a card's "My time" with 6)
-- now matches several → "Could not choose the best candidate function".
-- Drop every stale signature; keep ONLY the final 13-arg version (…, p_details).
-- ============================================================

drop function if exists forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric);
drop function if exists forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric, jsonb);
drop function if exists forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric, jsonb, guild_level);
drop function if exists forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric, jsonb, guild_level, uuid, uuid);

notify pgrst, 'reload schema';
