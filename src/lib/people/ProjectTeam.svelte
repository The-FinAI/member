<script lang="ts">
  // BUILD PLAN P7A — clean Team & Needs for a project (replaces the old
  // SlotSeater / ProjectSlotCard / ResourceForgeForm-need). The project page
  // SHOWS the team and posts needs; the actual matching happens on People
  // (MatchBoard) — keeping demand (Projects) and supply (People) on the two
  // domain surfaces, per PRD §3.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import NeedPost from '$lib/people/NeedPost.svelte';
  import Icon from '$lib/Icon.svelte';
  import MatchBoard from '$lib/people/MatchBoard.svelte';
  import { toast } from '$lib/toast';
  import { confirm } from '$lib/confirm';

  // canMatch: the viewer can assign people (chapter officer / admin) → the
  // matcher is embedded here so seating happens in place, not on People.
  let { projectId, canManage = false, canMatch = false, finished = false }: {
    projectId: string; canManage?: boolean; canMatch?: boolean; finished?: boolean;
  } = $props();

  type Member = { id: string; name: string; role: string; amount: number; unit: string; str: number; slotIds: string[] };
  type Need = { id: string; kind: string; skill: string | null; skill_id: string | null; level: string | null; resource: string | null; resource_type_id: string | null; quota: number | null; unit: string; filled: number; headcount: number };

  const LEVEL_LABEL: Record<string, string> = { learning: 'Learning', independent: 'Independent', lead: 'Lead' };

  let team = $state<Member[]>([]);
  let needs = $state<Need[]>([]);
  let editing = $state<Need | null>(null);
  let leaderName = $state<string | null>(null);
  let loading = $state(true);

  async function load() {
    if (!supabaseConfigured || !projectId) { loading = false; return; }
    loading = true;
    const [{ data: wc }, { data: sl }] = await Promise.all([
      supabase.from('work_commitment')
        .select('member_id, slot_id, monthly_amount, nominal_str, slot:slot_id(slot_kind), member:member_id(full_name), resource:resource_id(unit)')
        .eq('project_id', projectId),
      supabase.from('project_slot')
        .select('id, slot_kind, skill_id, resource_type_id, desired_level, quota, headcount, status, skill:skill_id(name), resource_type:resource_type_id(name, unit)')
        .eq('project_id', projectId)
    ]);
    // team: dedupe by member, label leader/contributor
    const byM: Record<string, Member> = {};
    for (const w of (wc as any[]) ?? []) {
      const id = w.member_id; if (!id) continue;
      const role = w.slot?.slot_kind === 'leader' ? 'first author'
                 : w.slot?.slot_kind === 'work_resource' ? 'resource' : 'contributor';
      const ex = byM[id];
      if (ex) { ex.amount += Number(w.monthly_amount) || 0; ex.str += Number(w.nominal_str) || 0; if (role === 'first author') ex.role = role; if (w.slot_id) ex.slotIds.push(w.slot_id); }
      else byM[id] = { id, name: w.member?.full_name ?? '—', role, amount: Number(w.monthly_amount) || 0, unit: w.resource?.unit ?? 'h', str: Number(w.nominal_str) || 0, slotIds: w.slot_id ? [w.slot_id] : [] };
    }
    team = Object.values(byM).sort((a, b) => Number(b.role === 'first author') - Number(a.role === 'first author'));
    leaderName = team.find((m) => m.role === 'first author')?.name ?? null;

    // needs: filled per slot
    const slots = (sl as any[]) ?? [];
    const filled: Record<string, number> = {};
    for (const w of (wc as any[]) ?? []) if (w.slot_id ?? false) {} // counted below by slot
    const { data: f } = await supabase.from('work_commitment').select('slot_id, member_id').eq('project_id', projectId);
    const setBy: Record<string, Set<string>> = {};
    for (const r of (f as any[]) ?? []) if (r.slot_id) (setBy[r.slot_id] ??= new Set()).add(r.member_id);
    needs = slots.filter((s) => s.status === 'open').map((s) => ({
      id: s.id, kind: s.slot_kind,
      skill: s.skill?.name ?? null, skill_id: s.skill_id ?? null, level: s.desired_level,
      resource: s.resource_type?.name ?? null, resource_type_id: s.resource_type_id ?? null,
      quota: s.quota, unit: s.slot_kind === 'work_resource' ? (s.resource_type?.unit ?? '') : 'h',
      filled: setBy[s.id]?.size ?? 0, headcount: s.headcount ?? 1
    }));
    loading = false;
  }
  $effect(() => { projectId; load(); });

  let removing = $state<string | null>(null);
  // #33/#34: an assignment must be removable. Confirms, then unassigns the
  // member from every need they hold on this project, re-opening those needs.
  async function removeMember(m: Member) {
    const ok = await confirm({
      title: $t('Remove {who} from the team?', { who: m.name }),
      body: m.role === 'first author'
        ? $t('This frees the first-author seat — it reopens as a need you can fill again.')
        : $t('This frees their role — it reopens as a need.'),
      confirmLabel: $t('Remove'),
      tone: 'danger'
    });
    if (!ok) return;
    removing = m.id;
    for (const slotId of m.slotIds) {
      const { error } = await supabase.rpc('unassign', { p_slot: slotId, p_member: m.id });
      if (error) { toast.error(error.message); removing = null; return; }
    }
    removing = null;
    toast.success($t('Removed {who}', { who: m.name }));
    await load();
  }
</script>

<section class="pt">
  <!-- first author shown for context; an OPEN first-author seat appears in
       Open needs below and is filled by the matcher right here on the project -->
  <div class="pt-lead">
    <span class="pt-lead-l">{$t('First author')}</span>
    {#if leaderName}<span class="pt-lead-n">{leaderName}</span>{:else}<span class="pt-lead-open">{$t('open — fill it in Open needs below')}</span>{/if}
  </div>

  <div class="pt-head"><span class="pt-h">{$t('Team')}</span></div>
  {#if loading}
    <p class="pt-dim">{$t('Loading…')}</p>
  {:else}
    {#if team.length}
      <div class="pt-team">
        {#each team as m (m.id)}
          <div class="tchip" class:busy={removing === m.id}>
            <a class="tc-link" href={`/members/${m.id}`}>
              <span class="tc-name">{m.name}</span>
              <span class="tc-role">{$t(m.role)}{#if m.amount} · {m.amount}{m.unit}{/if}</span>
              {#if m.str}<span class="tc-str">+{m.str.toLocaleString()} STR</span>{/if}
            </a>
            {#if canMatch && !finished && m.slotIds.length}
              <button class="tc-x" title={$t('Remove from team')} aria-label={$t('Remove from team')}
                disabled={removing === m.id} onclick={() => removeMember(m)}><Icon name="close" size={12} /></button>
            {/if}
          </div>
        {/each}
      </div>
    {:else}
      <p class="pt-dim">{$t('No one on the project yet.')}</p>
    {/if}

    <div class="pt-head" style="margin-top:1rem;"><span class="pt-h">{$t('Open needs')}</span></div>
    {#if canManage && !finished}
      <NeedPost projectId={projectId} onPosted={load} />
    {/if}

    {#if canMatch && !finished}
      <!-- assign in place: the matcher, scoped to this project's needs -->
      <MatchBoard projectId={projectId} embedded onAssigned={load} />
    {:else if needs.length}
      <div class="pt-needs">
        {#each needs as n (n.id)}
          {#if editing?.id === n.id}
            <NeedPost projectId={projectId} edit={{ id: n.id, kind: n.kind, skill_id: n.skill_id, level: n.level, resource_type_id: n.resource_type_id, quota: n.quota, headcount: n.headcount }}
              onSaved={() => { editing = null; load(); }} />
          {:else}
            <div class="nrow">
              {#if n.kind === 'leader'}
                <span class="n-skill">{$t('First author')}</span><span class="n-kind">{$t('leader')}</span>
              {:else if n.kind === 'work_resource'}
                <span class="n-skill">{n.resource}</span><span class="n-kind">{$t('resource')}</span>
              {:else}
                <span class="n-skill">{n.skill}</span>
                {#if n.level}<span class="n-lvl">{$t(LEVEL_LABEL[n.level] ?? n.level)}</span>{/if}
              {/if}
              {#if n.quota}<span class="n-q">{n.quota}{n.unit}</span>{/if}
              <span class="n-fill">{n.filled}/{n.headcount}</span>
              {#if canManage && !finished && n.kind !== 'leader' && n.filled === 0}
                <button class="n-edit" title={$t('Edit this need')} onclick={() => (editing = n)}><Icon name="edit" size={12} /></button>
              {/if}
            </div>
          {/if}
        {/each}
      </div>
      <p class="pt-dim pt-note">{$t('A chapter officer assigns people to these needs — from here.')}</p>
    {:else}
      <p class="pt-dim">{$t('No open needs.')}</p>
    {/if}
  {/if}
</section>

<style>
  .pt { margin: .5rem 0; }
  .pt-lead { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .8rem; padding-bottom: .6rem; border-bottom: 1px solid var(--line, #f0f0f0); }
  .pt-lead-l { font-weight: 600; font-size: .82rem; color: var(--muted, #777); }
  .pt-lead-n { font-weight: 600; }
  .pt-lead-open { color: var(--muted, #aaa); font-style: italic; }
  .pt-lead-set { border: 1px dashed var(--line, #ddd); background: none; border-radius: var(--r-sm); padding: .2rem .6rem; cursor: pointer; color: var(--muted, #777); font-size: .82rem; }
  .pt-lead-set:hover { border-color: var(--accent, var(--accent)); color: var(--accent, var(--accent)); }
  .pt-lead select { padding: .25rem .4rem; border: 1px solid var(--line, #ddd); border-radius: var(--r-sm); }
  .pt-lead-h { width: 3.6rem; padding: .25rem .3rem; border: 1px solid var(--line, #ddd); border-radius: var(--r-sm); }
  .pt-go { border: none; background: var(--accent, var(--accent)); color: #fff; border-radius: var(--r-sm); padding: .25rem .7rem; cursor: pointer; }
  .pt-go:disabled { opacity: .5; }
  .pt-ghost { border: 1px solid var(--line, #ddd); background: none; border-radius: var(--r-sm); padding: .25rem .6rem; cursor: pointer; }
  .pt-err { color: var(--neg, var(--down)); font-size: .8rem; }
  .pt-head { margin-bottom: .4rem; }
  .pt-h { font-weight: 600; font-size: .92rem; }
  .pt-dim { color: var(--muted, #999); font-size: .88rem; }
  .pt-note { margin-top: .4rem; }
  .pt-team { display: flex; flex-wrap: wrap; gap: .45rem; }
  .tchip { display: flex; align-items: stretch; gap: .25rem; border: 1px solid var(--line, #eee); border-radius: var(--r-sm); }
  .tchip:hover { border-color: var(--accent, var(--accent)); }
  .tchip.busy { opacity: .5; }
  .tc-link { display: flex; flex-direction: column; text-decoration: none; color: inherit; padding: .35rem .6rem; flex: 1; }
  .tc-x { border: none; background: none; color: var(--muted, #999); cursor: pointer; padding: 0 .35rem;
    border-left: 1px solid var(--line, #eee); display: flex; align-items: center; }
  .tc-x:hover { color: var(--down); }
  .tc-x:disabled { opacity: .5; cursor: default; }
  .tc-name { font-weight: 500; font-size: .88rem; }
  .tc-role { font-size: .74rem; color: var(--muted, #999); }
  .tc-str { font-size: .72rem; font-weight: 700; color: var(--gold, #94731b); font-family: var(--font-mono, monospace); }
  .pt-needs { display: flex; flex-direction: column; gap: .35rem; margin-top: .4rem; }
  .nrow { display: flex; align-items: center; gap: .6rem; padding: .35rem .5rem; border: 1px solid var(--line, #f0f0f0); border-radius: var(--r-sm); }
  .n-skill { font-weight: 500; }
  .n-kind { font-size: .72rem; color: var(--muted, #aaa); }
  .n-edit { margin-left: auto; border: 1px solid var(--line, #ddd); background: none; border-radius: var(--r-sm);
    padding: .05rem .4rem; cursor: pointer; color: var(--muted, #888); font-size: .8rem; }
  .n-edit:hover { border-color: var(--accent, var(--accent)); color: var(--accent, var(--accent)); }
  .n-lvl { font-size: .72rem; border: 1px solid var(--info); color: var(--info); border-radius: var(--r-full); padding: 0 .4rem; }
  .n-q { font-size: .78rem; color: var(--muted, #aaa); }
  .n-fill { margin-left: auto; font-size: .78rem; color: var(--muted, #888); }
</style>
