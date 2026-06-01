import { writable, derived } from 'svelte/store';
import { dict } from './messages';

// Lightweight i18n for the SPA. The *English source string is the key*: pages
// wrap literals in $t('Sign in'); only zh/ja/fr translations live in messages.ts,
// and any missing translation falls back to the English key — so the app never
// shows a blank and translation can roll out incrementally.

export type Locale = 'en' | 'zh' | 'ja' | 'fr';

export const LOCALES: { code: Locale; label: string; short: string }[] = [
  { code: 'en', label: 'English', short: 'EN' },
  { code: 'zh', label: '简体中文', short: '中' },
  { code: 'ja', label: '日本語', short: '日' },
  { code: 'fr', label: 'Français', short: 'FR' }
];

const STORAGE_KEY = 'locale';

function isLocale(v: string | null): v is Locale {
  return v === 'en' || v === 'zh' || v === 'ja' || v === 'fr';
}

function initial(): Locale {
  if (typeof document !== 'undefined') {
    const fromAttr = document.documentElement.getAttribute('lang');
    if (isLocale(fromAttr)) return fromAttr;
  }
  if (typeof localStorage !== 'undefined') {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (isLocale(saved)) return saved;
  }
  if (typeof navigator !== 'undefined') {
    const nav = navigator.language.toLowerCase();
    if (nav.startsWith('zh')) return 'zh';
    if (nav.startsWith('ja')) return 'ja';
    if (nav.startsWith('fr')) return 'fr';
  }
  return 'en';
}

export const locale = writable<Locale>(initial());

export function setLocale(l: Locale) {
  locale.set(l);
  if (typeof document !== 'undefined') document.documentElement.setAttribute('lang', l);
  try { localStorage.setItem(STORAGE_KEY, l); } catch { /* ignore */ }
}

function interpolate(s: string, vars?: Record<string, string | number>): string {
  if (!vars) return s;
  return s.replace(/\{(\w+)\}/g, (_, k) => (k in vars ? String(vars[k]) : `{${k}}`));
}

/** Reactive translator. Usage in markup: {$t('Sign in')} or {$t('{n} done', { n })}. */
export const t = derived(locale, ($l) => {
  return (key: string, vars?: Record<string, string | number>): string => {
    if ($l === 'en') return interpolate(key, vars);
    const table = dict[$l];
    const hit = table?.[key];
    return interpolate(hit ?? key, vars);
  };
});
