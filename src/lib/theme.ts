import { writable } from 'svelte/store';

export type Theme = 'dark' | 'light';

function initial(): Theme {
  if (typeof document !== 'undefined') {
    const t = document.documentElement.getAttribute('data-theme');
    if (t === 'light' || t === 'dark') return t;
  }
  return 'light';
}

export const theme = writable<Theme>(initial());

export function toggleTheme() {
  theme.update((t) => {
    const next: Theme = t === 'dark' ? 'light' : 'dark';
    if (typeof document !== 'undefined') {
      document.documentElement.setAttribute('data-theme', next);
      try { localStorage.setItem('theme', next); } catch { /* ignore */ }
    }
    return next;
  });
}
