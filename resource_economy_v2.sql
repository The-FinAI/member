-- ============================================================
-- Resource valuation v2 — normalise everything to USD, then to STR.
--
-- A resource TYPE declares HOW it is valued (valuation_method):
--   * 'gpu'  — pick a GPU model (built-in TFLOPs); monthly quantity is
--              GPU-hours.  USD = TFLOPs × hours × usd_per_tflop_hour
--   * 'api'  — pick an API model (built-in $/1M tokens); quantity is
--              millions of tokens.  USD = usd_per_million × M-tokens
--   * 'usd'  — quantity is US dollars.  USD = quantity
--   * 'flat' — quantity × the type's usd_per_unit (e.g. an expert-hour)
--
-- Everything lands in USD, then mints  STR = round(USD × str_per_usd).
-- The anchor is calibrated so a standard labour hour stays aligned:
--   usd_per_labor_hour 50 × str_per_usd 0.2 = 10 STR = paper_writing_rate.
-- So GPU/API/funding and human time all price on one consistent scale.
--
-- Built-in GPU + API catalogues hold just the common models; admins edit.
-- Idempotent: safe to re-run.
-- ============================================================

-- ---------- 1. valuation method + USD-per-unit on the type ----------
alter table resource_type add column if not exists valuation_method text not null default 'flat'
  check (valuation_method in ('flat', 'usd', 'gpu', 'api'));
alter table resource_type add column if not exists usd_per_unit numeric;   -- USD value of one unit (flat/usd types)

-- ---------- 2. anchor + compute-price policies ----------
insert into stater_policy (key, value, description) values
  ('str_per_usd',        0.2,   'STR minted per US dollar of resource value (anchor; $50 labour-hour = 10 STR)'),
  ('usd_per_tflop_hour', 0.005, 'Cloud-equivalent USD per TFLOP-hour of GPU compute'),
  ('usd_per_labor_hour', 50,    'Reference USD value of one standard labour hour (alignment only)')
on conflict (key) do nothing;

-- ---------- 3. built-in GPU catalogue (FP16/BF16 dense tensor TFLOPs) ----------
create table if not exists gpu_model (
  id        uuid primary key default gen_random_uuid(),
  name      text unique not null,
  tflops    numeric not null,                 -- FP16/BF16 dense tensor throughput
  rank      integer not null default 100,
  is_active boolean not null default true
);
insert into gpu_model (name, tflops, rank) values
  ('NVIDIA H100',    990, 10),
  ('NVIDIA A100',    312, 20),
  ('NVIDIA V100',    125, 30),
  ('NVIDIA RTX 4090', 165, 40),
  ('NVIDIA T4',       65, 50)
on conflict (name) do nothing;

-- ---------- 4. built-in API catalogue (blended USD per 1M tokens) ----------
create table if not exists api_model (
  id              uuid primary key default gen_random_uuid(),
  provider        text not null,
  name            text not null,
  usd_per_million numeric not null,           -- blended input+output per 1M tokens
  rank            integer not null default 100,
  is_active       boolean not null default true,
  unique (provider, name)
);
insert into api_model (provider, name, usd_per_million, rank) values
  ('OpenAI',    'GPT-4o',          7.5, 10),
  ('OpenAI',    'GPT-4o mini',     0.4, 20),
  ('Anthropic', 'Claude Sonnet',   9.0, 30),
  ('Google',    'Gemini 1.5 Pro',  5.0, 40),
  ('DeepSeek',  'DeepSeek-V3',     0.5, 50)
on conflict (provider, name) do nothing;

-- ---------- 5. a resource may point at a model ----------
alter table resource add column if not exists gpu_model_id uuid references gpu_model (id) on delete set null;
alter table resource add column if not exists api_model_id uuid references api_model (id) on delete set null;

-- ---------- 6. classify + recalibrate the seeded types ----------
update resource_type set valuation_method = 'gpu', unit = 'GPU-hour'   where name = 'Compute / GPU';
update resource_type set valuation_method = 'api', unit = '1M tokens'  where name = 'API Credits';
update resource_type set valuation_method = 'usd', unit = 'USD', usd_per_unit = 1 where name = 'Funding / Budget';
-- flat types: a USD value per unit (× str_per_usd 0.2 reproduces sane STR)
update resource_type set valuation_method = 'flat', unit = 'dataset', usd_per_unit = 200 where name = 'Dataset / Data Access';
update resource_type set valuation_method = 'flat', unit = 'hour',    usd_per_unit = 20  where name = 'Annotation Labor';
update resource_type set valuation_method = 'flat', unit = 'seat',    usd_per_unit = 25  where name = 'Software / License';
update resource_type set valuation_method = 'flat', unit = 'hour',    usd_per_unit = 75  where name = 'Expert Time';
update resource_type set valuation_method = 'flat', unit = 'hour',    usd_per_unit = 50  where name = 'Labor';
update resource_type set valuation_method = 'flat', unit = 'unit',    usd_per_unit = 5   where name = 'Other';
-- any remaining flat type without a USD price falls back to its old str_per_unit / anchor
update resource_type set usd_per_unit = coalesce(usd_per_unit,
                          case when str_per_unit > 0 then str_per_unit / 0.2 else 1 end)
  where valuation_method = 'flat' and usd_per_unit is null;

-- ---------- 7. effective USD value of qty units of a resource ----------
create or replace function resource_value_usd(res uuid, qty numeric)
returns numeric language plpgsql stable security definer set search_path = public as $$
declare meth text; tf numeric; upm numeric; upu numeric;
begin
  select rt.valuation_method,
         gm.tflops,
         am.usd_per_million,
         coalesce(r.usd_per_unit, rt.usd_per_unit)
    into meth, tf, upm, upu
  from resource r
  join resource_type rt on rt.id = r.type_id
  left join gpu_model gm on gm.id = r.gpu_model_id
  left join api_model am on am.id = r.api_model_id
  where r.id = res;

  if meth is null then return 0; end if;
  return case meth
    when 'gpu' then coalesce(tf, 0)  * qty * stater_policy_num('usd_per_tflop_hour', 0.005)
    when 'api' then coalesce(upm, 0) * qty
    when 'usd' then qty
    else            coalesce(upu, 0) * qty
  end;
end; $$;
grant execute on function resource_value_usd(uuid, numeric) to authenticated;

-- ---------- 8. quantity unit label for a resource ----------
create or replace function resource_qty_unit(res uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(nullif(r.unit, ''), nullif(rt.unit, ''),
                  case rt.valuation_method when 'gpu' then 'GPU-hour'
                                           when 'api' then '1M tokens'
                                           when 'usd' then 'USD' else 'unit' end)
  from resource r join resource_type rt on rt.id = r.type_id where r.id = res;
$$;
grant execute on function resource_qty_unit(uuid) to authenticated;

-- ---------- 9. declare = mint, valued through USD ----------
create or replace function set_resource_commitment(p uuid, res uuid, ym text, qty numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; cid uuid; usd numeric; equiv integer; appr text; holder uuid; scp text;
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
  if scp = 'member' and holder is not null and holder <> me then
    raise exception 'only the resource holder can commit it';
  end if;

  select id into cid from stater_project_stake_commitment
   where project_id = p and member_id = me and commitment_type = 'resource' and resource_id = res
   limit 1;
  if cid is null then
    insert into stater_project_stake_commitment
      (project_id, member_id, commitment_type, resource_id, status)
    values (p, me, 'resource', res, 'verified') returning id into cid;
  end if;

  usd   := resource_value_usd(res, qty);
  equiv := ceil(usd * stater_policy_num('str_per_usd', 0.2));

  insert into stater_commitment_period (commitment_id, year_month, committed_amount, token_equivalent, status)
  values (cid, ym, qty, equiv, 'minted')
  on conflict (commitment_id, year_month)
  do update set committed_amount = excluded.committed_amount,
                token_equivalent = excluded.token_equivalent,
                status = 'minted';
  return cid;
end; $$;
grant execute on function set_resource_commitment(uuid, uuid, text, numeric) to authenticated;

-- ---------- 10. RLS + grants for the catalogues ----------
alter table gpu_model enable row level security;
alter table api_model enable row level security;
drop policy if exists read_gpu_model on gpu_model;
create policy read_gpu_model on gpu_model for select to authenticated using (true);
drop policy if exists manage_gpu_model on gpu_model;
create policy manage_gpu_model on gpu_model for all to authenticated
  using (has_capability('manage_resources')) with check (has_capability('manage_resources'));
drop policy if exists read_api_model on api_model;
create policy read_api_model on api_model for select to authenticated using (true);
drop policy if exists manage_api_model on api_model;
create policy manage_api_model on api_model for all to authenticated
  using (has_capability('manage_resources')) with check (has_capability('manage_resources'));

grant select on gpu_model, api_model to anon, authenticated;
grant insert, update, delete on gpu_model, api_model to authenticated;

notify pgrst, 'reload schema';
