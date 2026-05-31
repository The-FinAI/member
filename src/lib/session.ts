import { writable } from 'svelte/store';
import type { Session } from '@supabase/supabase-js';

export type Member = {
  id: string;
  full_name: string;
  email: string;
  affiliation: string | null;
  status: string;
};

export const session = writable<Session | null>(null);
export const member = writable<Member | null>(null);
/** capability keys the current user holds, derived from their positions */
export const capabilities = writable<Set<string>>(new Set());
export const authReady = writable(false);

export function hasCap(caps: Set<string>, key: string): boolean {
  return caps.has(key);
}
