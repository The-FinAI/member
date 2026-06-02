insert into announcement (title, body, href, cta_label, level, pinned, is_active)
select 'The Guild is open — mint & claim your role cards',
       'Every Chapter and Working Group bootstraps the Guild first.',
       '/skills', 'Open the Guild →', 'info', true, true
where not exists (select 1 from announcement);
