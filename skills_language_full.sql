-- Restore the full language set. Additive, idempotent.

begin;

insert into skill (parent_id, name)
select l.id, v.name
from (values
  ('French'), ('German'), ('Portuguese'), ('Arabic'), ('Russian'), ('Hindi')
) as v(name)
cross join (select id from skill where name = 'Language' and parent_id is null) l
where not exists (
  select 1 from skill s where s.parent_id = l.id and s.name = v.name
);

commit;
