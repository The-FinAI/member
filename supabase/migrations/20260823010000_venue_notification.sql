-- Venue notification (decision-announcement) date, kept fresh by the weekly
-- sync-venues GitHub Action (ccfddl). Used as the default "result date" for
-- projects under review; project.deadline still overrides per project.
alter table venue add column if not exists notification date;
