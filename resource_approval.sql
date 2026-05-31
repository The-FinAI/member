-- ============================================================
-- Resource approval workflow.
-- New member-added resources start 'pending' and must be approved
-- by a manage_resources steward before they can be offered to projects.
-- A trigger enforces the status server-side so members can't self-approve.
-- ============================================================
alter table resource
  add column if not exists approval_status text not null default 'pending'
  check (approval_status in ('pending', 'approved', 'rejected'));

-- grandfather every resource that already exists into 'approved'
update resource set approval_status = 'approved' where approval_status = 'pending';

-- guard: only manage_resources stewards may set/alter the approval status
create or replace function _resource_approval_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if has_capability('manage_resources') then
    return new;                       -- stewards may set any status
  end if;
  if tg_op = 'INSERT' then
    new.approval_status := 'pending'; -- members always start pending
  elsif tg_op = 'UPDATE' then
    new.approval_status := old.approval_status;  -- members can't change it
  end if;
  return new;
end; $$;

drop trigger if exists resource_approval_guard on resource;
create trigger resource_approval_guard
  before insert or update on resource
  for each row execute function _resource_approval_guard();

notify pgrst, 'reload schema';
