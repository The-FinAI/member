<script lang="ts">
  // BUILD PLAN P7A — clean Team & Needs for a project (replaces the old
  // SlotSeater / ProjectSlotCard / ResourceForgeForm-need). The project page
  // SHOWS the team and posts needs; the actual matching happens on People
  // (MatchBoard) — keeping demand (Projects) and supply (People) on the two
  // domain surfaces, per PRD §3.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import NeedPost from '$lib/people/NeedPost.svelte';

  let { projectId, canManage = false, finished = false }: {
    projectId: string; canManage?: boolean; finished?: boolean;
  } = $props();

  type Member = { id: string; name: string; role: string; amount: number; unit: string };
  type Need = { id: string; kind: string; skill: string | null; level: string | null; resource: string | null; quota: number | null; unit: string; filled: number; headcount: number };

  const LEVEL_LABEL: Record<string, string> = { learning: 'Learning', independent: 'Independent', lead: 'Lead' };

  let team = $state<Member[]>([]);
  let needs = $state<Need[]>([]);
  let loading = $state(true);

  async function load() {
    if (!supabaseConfigured || !projectId) { loading = false; return; }
    loading = true;
    const [{ data: wc }, { data: sl }] = await Promise.all([
      supabase.from('work_commitment')
        .select('member_id, monthly_amount, slot:slot_id(slot_kind), member:member_id(full_name), resource:resource_id(unit)')
        .eq('project_id', projectId),
      supabase.from('project_slot')
        .select('id, slot_kind, desired_level, quota, headcount, status, skill:skill_id(name), resource_type:resource_type_id(name, unit)')
        .eq('project_id', projectId)
    ]);
    // team: dedupe by member, label leader/contributor
    const byM: Record<string, Member> = {};
    for (const w of (wc as any[]) ?? []) {
      const id = w.member_id; if (!id) continue;
      const role = w.slot?.slot_kind === 'leader' ? 'first author'
                 : w.slot?.slot_kind === 'work_resource' ? 'resource' : 'contributor';
      const ex = byM[id];
      if (ex) { ex.amount += Number(w.monthly_amount) || 0; if (role === 'first author') ex.role = role; }
      else byM[id] = { id, name: w.member?.full_name ?? '—', role, amount: Number(w.monthly_amount) || 0, unit: w.resource?.unit ?? 'h' };
    }
    team = Object.values(byM).sort((a, b) => Number(b.role === 'first author') - Number(a.role === 'first author'));

    // needs: filled per slot
    const slots = (sl as any[]) ?? [];
    const filled: Record<string, number> = {};
    for (const w of (wc as any[]) ?? []) if (w.slot_id ?? false) {} // counted below by slot
    const { data: f } = await supabase.from('work_commitment').select('slot_id, member_id').eq('project_id', projectId);
    const setBy: Record<string, Set<string>> = {};
    for (const r of (f as any[]) ?? []) if (r.slot_id) (setBy[r.slot_id] ??= new Set()).add(r.member_id);
    needs = slots.filter((s) => s.status === 'open' && s.slot_kind !== 'leader').map((s) => ({
      id: s.id, kind: s.slot_kind,
      skill: s.skill?.name ?? null, level: s.desired_level,
      resource: s.resource_type?.name ?? null,
      quota: s.quota, unit: s.slot_kind === 'work_resource' ? (s.resource_type?.unit ?? '') : 'h',
      filled: setBy[s.id]?.size ?? 0, headcount: s.headcount ?? 1
    }));
    loading = false;
  }
  $effect(() => { projectId; load(); });
</script>

<section class="pt">
  <div class="pt-head"><span class="pt-h">{$t('Team')}</span></div>
  {#if loading}
    <p class="pt-dim">{$t('Loading…')}</p>
  {:else}
    {#if team.length}
      <div class="pt-team">
        {#each team as m (m.id)}
          <a class="tchip" href={`/members/${m.id}`}>
            <span class="tc-name">{m.name}</span>
            <span class="tc-role">{$t(m.role)}{#if m.amount} · {m.amount}{m.unit}{/if}</span>
          </a>
        {/each}
      </div>
    {:else}
      <p class="pt-dim">{$t('No one on the project yet.')}</p>
    {/if}

    <div class="pt-head" style="margin-top:1rem;"><span class="pt-h">{$t('Open needs')}</span></div>
    {#if canManage && !finished}
      <NeedPost projectId={projectId} onPosted={load} />
    {/if}
    {#if needs.length}
      <div class="pt-needs">
        {#each needs as n (n.id)}
          <div class="nrow">
            {#if n.kind === 'work_resource'}
              <span class="n-skill">{n.resource}</span><span class="n-kind">{$t('resource')}</span>
            {:else}
              <span class="n-skill">{n.skill}</span>
              {#if n.level}<span class="n-lvl">{$t(LEVEL_LABEL[n.level] ?? n.level)}</span>{/if}
            {/if}
            {#if n.quota}<span class="n-q">{n.quota}{n.unit}</span>{/if}
            <span class="n-fill">{n.filled}/{n.headcount}</span>
          </div>
        {/each}
      </div>
      <p class="pt-dim pt-note">{$t('Matching happens on People — a chapter steward places people into these needs.')}</p>
    {:else}
      <p class="pt-dim">{$t('No open needs.')}</p>
    {/if}
  {/if}
</section>

<style>
  .pt { margin: .5rem 0; }
  .pt-head { margin-bottom: .4rem; }
  .pt-h { font-weight: 600; font-size: .92rem; }
  .pt-dim { color: var(--muted, #999); font-size: .88rem; }
  .pt-note { margin-top: .4rem; }
  .pt-team { display: flex; flex-wrap: wrap; gap: .45rem; }
  .tchip { display: flex; flex-direction: column; text-decoration: none; color: inherit; border: 1px solid var(--line, #eee); border-radius: 9px; padding: .35rem .6rem; }
  .tchip:hover { border-color: var(--accent, #6a7cff); }
  .tc-name { font-weight: 500; font-size: .88rem; }
  .tc-role { font-size: .74rem; color: var(--muted, #999); }
  .pt-needs { display: flex; flex-direction: column; gap: .35rem; margin-top: .4rem; }
  .nrow { display: flex; align-items: center; gap: .6rem; padding: .35rem .5rem; border: 1px solid var(--line, #f0f0f0); border-radius: 8px; }
  .n-skill { font-weight: 500; }
  .n-kind { font-size: .72rem; color: var(--muted, #aaa); }
  .n-lvl { font-size: .72rem; border: 1px solid #8aa0ff; color: #5566cc; border-radius: 999px; padding: 0 .4rem; }
  .n-q { font-size: .78rem; color: var(--muted, #aaa); }
  .n-fill { margin-left: auto; font-size: .78rem; color: var(--muted, #888); }
</style>
