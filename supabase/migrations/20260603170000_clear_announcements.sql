-- Clear the launch banner: retire every active announcement (one-time).
-- Records are kept (is_active=false) for the admin announcements log; admins
-- post fresh notices from /admin/announcements.
update announcement set is_active = false, pinned = false where is_active;
