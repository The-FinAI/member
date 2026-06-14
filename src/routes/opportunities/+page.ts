import { redirect } from '@sveltejs/kit';

// The Task Market is now the "Open needs" view of Projects. Redirect at load
// time so Back doesn't bounce through /opportunities. (Issue #24.)
export const load = () => {
  throw redirect(307, '/projects?tab=needs');
};
