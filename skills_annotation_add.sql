-- Add data annotation/labeling as a first-class craft — core to dataset &
-- benchmark projects. Additive, idempotent.

begin;

insert into skill (parent_id, name)
select e.id, 'Data Annotation & Labeling'
from (select id from skill where name = 'Engineering' and parent_id is null) e
where not exists (
  select 1 from skill s where s.parent_id = e.id and s.name = 'Data Annotation & Labeling'
);

commit;
