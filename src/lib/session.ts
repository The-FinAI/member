import { writable } from 'svelte/store';
import type { Session } from '@supabase/supabase-js';

export type Member = {
  id: string;
  full_name: string;
  email: string;
  affiliation: string | null;
  status: string;
};

/** a chapter/working-group the current user serves as an officer of */
export type OfficerUnit = { unit_id: string; code: string; name: string; kind: string; role: string };
/** a card the current user is currently acting on behalf of (proxy) */
export type ActingCard = { id: string; full_name: string };

export const session = writable<Session | null>(null);
export const member = writable<Member | null>(null);
/** capability keys the current user holds, derived from their positions */
export const capabilities = writable<Set<string>>(new Set());
/** chapters / working groups the current user is a serving officer of */
export const officerUnits = writable<OfficerUnit[]>([]);
/** when set, member-scoped actions are performed as this card (p_as) */
export const actingAs = writable<ActingCard | null>(null);
export const authReady = writable(false);
/** a human-readable reason the last sign-in callback failed (expired link, etc.) */
export const authError = writable<string | null>(null);

export function hasCap(caps: Set<string>, key: string): boolean {
  return caps.has(key);
}
