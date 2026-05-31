import { supabase, supabaseConfigured } from './supabase';
import { member, capabilities, type Member } from './session';

/** Bind a pre-created (invited) member row to the just-authenticated user. */
export async function claimMembership(): Promise<void> {
  if (!supabaseConfigured) return;
  await supabase.rpc('claim_membership');
}

/** Load the current user's member row + derived capabilities into stores. */
export async function loadProfile(authUserId: string): Promise<void> {
  if (!supabaseConfigured) return;

  const { data: m } = await supabase
    .from('member')
    .select('id, full_name, email, affiliation, status')
    .eq('auth_user_id', authUserId)
    .maybeSingle();

  member.set((m as Member) ?? null);
  if (!m) {
    capabilities.set(new Set());
    return;
  }

  // capabilities = union of capability_key across the member's positions
  const { data: caps } = await supabase
    .from('member_position')
    .select('position(position_capability(capability_key))')
    .eq('member_id', (m as Member).id);

  const set = new Set<string>();
  for (const row of caps ?? []) {
    const pos = (row as any).position;
    for (const pc of pos?.position_capability ?? []) {
      if (pc?.capability_key) set.add(pc.capability_key);
    }
  }
  capabilities.set(set);
}

export function clearProfile(): void {
  member.set(null);
  capabilities.set(new Set());
}
