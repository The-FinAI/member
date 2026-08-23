import { redirect } from '@sveltejs/kit';

// The Market is the app. Redirect at load time so `/` never becomes a history
// entry (Back returns to the real previous page).
export const load = () => {
  throw redirect(307, '/market');
};
