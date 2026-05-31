-- ============================================================
-- Auto-populated venue deadlines from CCF-deadlines (ccfddl).
-- Snapshot as of 2026-05-31: next-or-latest published deadline.
-- Rolling venues (ARR, journals) left null. Re-run to refresh.
-- ============================================================

-- optional provenance column
alter table venue add column if not exists source_url text;

update venue set deadline = d.deadline::date, source_url = d.src
from (values
  ('AAAI',    '2026-07-27', 'https://aaai.org/conference/aaai/aaai-27/'),   -- AAAI 2027 (upcoming)
  ('NeurIPS', '2026-05-07', 'https://neurips.cc/Conferences/2026'),
  ('ICML',    '2026-01-29', 'https://icml.cc/Conferences/2026'),
  ('ICLR',    '2025-09-24', 'https://iclr.cc/Conferences/2026'),
  ('EMNLP',   '2026-05-25', 'https://2026.emnlp.org/'),
  ('ACL',     '2026-01-05', 'https://2026.aclweb.org/'),
  ('COLM',    '2026-03-31', 'https://colmweb.org'),
  ('MM',      '2026-04-01', 'https://2026.acmmm.org/'),
  ('WWW',     '2025-10-07', 'https://www2026.thewebconf.org/')
) as d(name, deadline, src)
where venue.name = d.name;

notify pgrst, 'reload schema';
