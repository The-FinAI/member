import { redirect } from '@sveltejs/kit';

// The Project Ledger is the single landing surface. Redirect at load time (not
// in onMount) so `/` is resolved to `/projects` before it becomes a history
// entry — pressing the browser Back button then returns to the real previous
// page instead of bouncing through `/`. (Issue #24.)
export const load = () => {
  throw redirect(307, '/projects');
};
