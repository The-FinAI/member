-- forge_resource / resource_value_usd reference resource.usd_per_unit and
-- resource.str_per_unit (the per-resource flat override), but the live resource
-- table never got these columns (the Phase-1 rebuild's resource table predates
-- them on an already-existing table). Add them. Idempotent.
alter table resource add column if not exists usd_per_unit numeric;
alter table resource add column if not exists str_per_unit numeric;
notify pgrst, 'reload schema';
