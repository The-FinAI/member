insert into announcement (title, body, href, cta_label, level, pinned, is_active)
select 'Phase 1 is live — forge your member cards',
       'Officers: forge a card for each researcher and claim your existing projects to begin.',
       '/officer', 'Open officer console →', 'info', true, true
where not exists (select 1 from announcement);
