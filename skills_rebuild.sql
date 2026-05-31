-- Rebuild the skill tree into 5 skill-type categories.
-- Safe: member_skill / skill_endorsement / open_need.skill_id are cleared first
-- (currently empty); 34 projects and all other data are untouched.

begin;

delete from member_skill;
delete from skill_endorsement;
update open_need set skill_id = null where skill_id is not null;
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
  ('Domain', 'Equities / Trading'),
  ('Domain', 'Risk Management'),
  ('Domain', 'Audit / Accounting / XBRL'),
  ('Domain', 'Portfolio / Asset Management'),
  ('Domain', 'Banking / Credit'),
  ('Domain', 'RegTech / Compliance'),
  ('Domain', 'Macroeconomics'),
  ('Domain', 'ESG / Sustainable Finance'),

  ('Language', 'English'),
  ('Language', 'Chinese'),
  ('Language', 'Japanese'),
  ('Language', 'Korean'),
  ('Language', 'Spanish'),
  ('Language', 'French'),
  ('Language', 'German'),
  ('Language', 'Portuguese'),
  ('Language', 'Arabic'),
  ('Language', 'Russian'),
  ('Language', 'Hindi'),

  ('Research', 'Paper Writing'),
  ('Research', 'Rebuttal / Review'),
  ('Research', 'Literature Review'),
  ('Research', 'Experiment Design'),
  ('Research', 'Benchmark Design'),
  ('Research', 'Evaluation & Metrics'),
  ('Research', 'Statistical Analysis'),

  ('Engineering', 'Pretraining'),
  ('Engineering', 'Fine-tuning / SFT'),
  ('Engineering', 'RLHF / Alignment'),
  ('Engineering', 'Inference & Serving'),
  ('Engineering', 'Data Engineering / Pipelines'),
  ('Engineering', 'Agent / Tool-use / RAG'),
  ('Engineering', 'Multimodal'),
  ('Engineering', 'Frontend / Backend Dev'),
  ('Engineering', 'Distributed Training / GPU'),

  ('Organization & Communication', 'Project Management / Coordination'),
  ('Organization & Communication', 'Meeting Facilitation / Hosting'),
  ('Organization & Communication', 'Minutes / Record-keeping'),
  ('Organization & Communication', 'Mentoring / Onboarding'),
  ('Organization & Communication', 'Presentation / Public Speaking'),
  ('Organization & Communication', 'Community Building / Outreach'),
  ('Organization & Communication', 'Cross-team Collaboration')
) as c(parent, name)
join skill p on p.name = c.parent and p.parent_id is null;

commit;
