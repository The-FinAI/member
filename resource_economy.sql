-- ============================================================
-- Resources as monthly, valued contributions.
--
-- Each resource TYPE carries a unit (GPU-hour, USD, credit…) and a default
-- STR-per-unit rate; an individual resource may override both. A holder
-- declares the month's quantity on a project and it mints nominal STR into
-- the pool (declare = mint) — exactly like labour and first-author writing,
-- so GPU is GPU-hours/month, funding is $/month, API is credits/month.
--
-- The request/offer matching flow is kept for discovery + author seating;
-- this layer adds the monthly economic quantity on top.
-- Idempotent: safe to re-run.
-- ============================================================

-- ---------- 1. unit + default rate on the type ----------
alter table resource_type add column if not exists unit text;
alter table resource_type add column if not exists str_per_unit numeric not null default 0;

-- ---------- 2. optional per-resource override ----------
alter table resource add column if not exists unit text;
alter table resource add column if not exists str_per_unit numeric;   -- null = inherit type

-- ---------- 3. seed sensible defaults (admins tune later) ----------
update resource_type set unit = 'GPU-hour', str_per_unit = 2    where name = 'Compute / GPU'         and unit is null;
update resource_type set unit = 'USD',      str_per_unit = 0.2  where name = 'Funding / Budget'      and unit is null;
update resource_type set unit = 'credit',   str_per_unit = 0.5  where name = 'API Credits'           and unit is null;
update resource_type set unit = 'dataset',  str_per_unit = 40   where name = 'Dataset / Data Access' and unit is null;
update resource_type set unit = 'hour',     str_per_unit = 8    where name = 'Annotation Labor'      and unit is null;
update resource_type set unit = 'seat',     str_per_unit = 5    where name = 'Software / License'    and unit is null;
update resource_type set unit = 'hour',     str_per_unit = 15   where name = 'Expert Time'           and unit is null;
update resource_type set unit = 'hour',     str_per_unit = 10   where name = 'Labor'                 and unit is null;
update resource_type set unit = 'unit',     str_per_unit = 1    where name = 'Other'                 and unit is null;
update resource_type set unit = 'unit'      where unit is null;   -- backfill any remaining

-- ---------- 4. effective unit / rate for a resource ----------
create or replace function resource_rate(res uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(
    (select r.str_per_unit from resource r where r.id = res and r.str_per_unit is not null),
    (select rt.str_per_unit from resource r join resource_type rt on rt.id = r.type_id where r.id = res),
    0);
$$;
create or replace function resource_unit(res uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select nullif(r.unit, '')  from resource r where r.id = res),
    (select nullif(rt.unit, '') from resource r join resource_type rt on rt.id = r.type_id where r.id = res),
    'unit');
$$;
grant execute on function resource_rate(uuid)  to authenticated;
grant execute on function resource_unit(uuid)  to authenticated;

-- ---------- 5. declare = mint the month's resource quantity ----------
-- Mirrors set_labor_commitment, but keyed on a resource (not a skill) and
-- valued at the resource's effective STR-per-unit rate.
create or replace function set_resource_commitment(p uuid, res uuid, ym text, qty numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; cid uuid; rate numeric; equiv integer; appr text; holder uuid; scp text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if res is null then raise exception 'a resource commitment needs a resource'; end if;
  if ym !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if qty < 0 then raise exception 'quantity cannot be negative'; end if;
  if not exists (select 1 from project_member where project_id = p and member_id = me) then
    raise exception 'join the project before committing a resource';
  end if;

  select approval_status, holder_member_id, scope into appr, holder, scp from resource where id = res;
  if appr is null then raise exception 'resource not found'; end if;
  if appr <> 'approved' then raise exception 'resource is not approved yet'; end if;
  -- a personal resource may only be committed by its holder
  if scp = 'member' and holder is not null and holder <> me then
    raise exception 'only the resource holder can commit it';
  end if;

  -- find or create the standing resource commitment for this member + resource
  select id into cid from stater_project_stake_commitment
   where project_id = p and member_id = me and commitment_type = 'resource' and resource_id = res
   limit 1;
  if cid is null then
    insert into stater_project_stake_commitment
      (project_id, member_id, commitment_type, resource_id, status)
    values (p, me, 'resource', res, 'verified') returning id into cid;
  end if;

  rate  := resource_rate(res);
  equiv := ceil(rate * qty);

  -- declare = mint: write the month's nominal straight into the pool accounting
  insert into stater_commitment_period (commitment_id, year_month, committed_amount, token_equivalent, status)
  values (cid, ym, qty, equiv, 'minted')
  on conflict (commitment_id, year_month)
  do update set committed_amount = excluded.committed_amount,
                token_equivalent = excluded.token_equivalent,
                status = 'minted';
  return cid;
end; $$;
grant execute on function set_resource_commitment(uuid, uuid, text, numeric) to authenticated;

notify pgrst, 'reload schema';
