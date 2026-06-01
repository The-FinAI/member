-- Trim the skill tree down to a lean guild skeleton (5 categories, 16 leaves).
-- Masters grow it back from here via branch_skill(). Clears holder/exam data
-- first (cascades would handle it, but we clear explicitly for clarity) and
-- nulls open_need.skill_id so the FK doesn't block the rebuild.

begin;

-- clear everything that references a skill
delete from skill_exam_vote;
delete from skill_exam;
delete from skill_exam_rubric;
delete from member_skill;
update open_need set skill_id = null where skill_id is not null;
update skill set master_member_id = null;   -- drop authorship before rebuild

delete from skill where parent_id is not null;
delete from skill where parent_id is null;

-- top-level categories
insert into skill (name) values
  ('Domain'),
  ('Language'),
  ('Research'),
  ('Engineering'),
  ('Organization & Communication');

-- leaf skills (parent matched by category name)
insert into skill (parent_id, name)
select p.id, c.name
from (values
  ('Domain', 'Financial Markets & Trading'),
  ('Domain', 'Risk & Compliance'),
  ('Domain', 'Accounting & Audit'),

  ('Language', 'English'),
  ('Language', 'Chinese'),
  ('Language', 'Japanese'),
  ('Language', 'Korean'),
  ('Language', 'Spanish'),

  ('Research', 'Academic Writing'),
  ('Research', 'Experiment Design'),
  ('Research', 'Evaluation & Benchmarking'),

  ('Engineering', 'LLM Training & Fine-tuning'),
  ('Engineering', 'Agent / RAG Systems'),
  ('Engineering', 'Data & Infrastructure'),

  ('Organization & Communication', 'Project Management'),
  ('Organization & Communication', 'Mentoring & Community')
) as c(parent, name)
join skill p on p.name = c.parent and p.parent_id is null;

commit;
