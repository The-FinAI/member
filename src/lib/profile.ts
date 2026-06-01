import { supabase, supabaseConfigured } from './supabase';
import { member, capabilities, officerUnits, actingAs, type Member, type OfficerUnit } from './session';

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
    officerUnits.set([]);
    return;
  }

  // org-unit officer roles the member currently serves (drives "My chapter")
  const { data: off } = await supabase
    .from('org_unit_officer')
    .select('role, org_unit:org_unit_id(id, code, name, kind)')
    .eq('member_id', (m as Member).id)
    .is('ended_on', null);
  officerUnits.set(
    ((off ?? []) as any[])
      .filter((r) => r.org_unit)
      .map((r) => ({
        unit_id: r.org_unit.id, code: r.org_unit.code, name: r.org_unit.name,
        kind: r.org_unit.kind, role: r.role
      })) as OfficerUnit[]
  );

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
  officerUnits.set([]);
  actingAs.set(null);
}
