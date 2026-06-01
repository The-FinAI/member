-- Expand the Engineering branch: split RAG out of "Agent / RAG Systems" and add
-- long-context, RL and FL. Additive + one rename (member_skill is empty so the
-- rename is safe). Idempotent-ish via NOT EXISTS guards.

begin;

-- RAG becomes its own leaf, so the agent node is just "Agent Systems"
update skill
   set name = 'Agent Systems'
 where name = 'Agent / RAG Systems'
   and parent_id = (select id from skill where name = 'Engineering' and parent_id is null);

insert into skill (parent_id, name)
select e.id, v.name
from (values
  ('Long-Context Modeling'),
  ('Retrieval-Augmented Generation (RAG)'),
  ('Reinforcement Learning (RL)'),
  ('Federated Learning (FL)')
) as v(name)
cross join (select id from skill where name = 'Engineering' and parent_id is null) e
where not exists (
  select 1 from skill s where s.parent_id = e.id and s.name = v.name
);

commit;
