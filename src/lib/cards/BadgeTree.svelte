<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  // Skill "talent tree": every certifiable skill (a leaf of the skill tree) is a
  // node with four ranks. A member's current badge fills the node solid; a
  // manager clicks ranks to stage raises across many skills, then submits the
  // whole batch at once via forge_badges (one review batch). Read-only otherwise.
  let { memberId, canEdit = false, onSubmitted }: {
    memberId: string;
    canEdit?: boolean;
    onSubmitted?: () => void;
  } = $props();

  const LEVELS = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = { apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master' };
  const RANK: Record<string, number> = { apprentice: 1, journeyman: 2, craftsman: 3, master: 4 };

  type Skill = { id: string; name: string; parent_id: string | null };
  let skills = $state<Skill[]>([]);
  let current = $state<Record<string, number>>({});   // skill_id -> rank 1..4 (0 = none)
  let draft = $state<Record<string, number>>({});      // staged rank (>= current)
  let loading = $state(true);
  let busy = $state(false); let err = $state(''); let msg = $state('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; err = ''; msg = '';
    const [{ data: sk }, { data: bg }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('badge').select('skill_id, level').eq('member_id', memberId)
    ]);
    skills = (sk as Skill[]) ?? [];
    const cur: Record<string, number> = {};
    for (const b of (bg as { skill_id: string; level: string }[]) ?? []) cur[b.skill_id] = RANK[b.level] ?? 0;
    current = cur; draft = { ...cur };
    loading = false;
  }

  // group leaf skills (certifiable) under their domain (parent)
  const domains = $derived.by(() => {
    const nameOf = (id: string | null) => (id ? skills.find((s) => s.id === id)?.name ?? '' : '');
    const parentIds = new Set(skills.map((s) => s.parent_id).filter(Boolean));
    const leaves = skills.filter((s) => !parentIds.has(s.id));
    const by = new Map<string, { domain: string; items: Skill[] }>();
    for (const s of leaves) {
      const key = s.parent_id ?? '_';
      if (!by.has(key)) by.set(key, { domain: nameOf(s.parent_id) || get(t)('General'), items: [] });
      by.get(key)!.items.push(s);
    }
    return [...by.values()].sort((a, b) => a.domain.localeCompare(b.domain));
  });

  const changes = $derived(skills.filter((s) => (draft[s.id] ?? 0) > (current[s.id] ?? 0)));
  const ownedCount = $derived(Object.values(current).filter((r) => r > 0).length);

  function setRank(skillId: string, rank: number) {
    if (!canEdit) return;
    const cur = current[skillId] ?? 0;
    // can't downgrade an existing badge; clicking at/below current clears any stage
    draft = { ...draft, [skillId]: rank <= cur ? cur : rank };
    err = ''; msg = '';
  }

  async function submit() {
    if (!changes.length) return;
    busy = true; err = ''; msg = '';
    const items = changes.map((s) => ({ skill: s.id, level: LEVELS[(draft[s.id] ?? 1) - 1] }));
    const { error: e } = await supabase.rpc('forge_badges', { p_member: memberId, p_items: items, p_as: memberId });
    busy = false;
    if (e) { err = e.message; return; }
    msg = get(t)('{n} badge change(s) submitted for review.', { n: changes.length });
    await load();
    onSubmitted?.();
  }

  let last = '';
  $effect(() => { if (memberId && memberId !== last) { last = memberId; load(); } });
</script>

{#if !loading}
  <div class="bt">
    {#if err}<p class="bt-err">{err}</p>{/if}
    {#if msg}<p class="bt-ok">{msg}</p>{/if}

    {#if !canEdit && ownedCount === 0}
      <p class="bt-muted">{$t('No badges yet.')}</p>
    {/if}

    <div class="bt-domains">
      {#each domains as d (d.domain)}
        {@const owned = d.items.filter((s) => (current[s.id] ?? 0) > 0)}
        {#if canEdit || owned.length}
          <div class="bt-domain">
            <span class="bt-dh">{d.domain}</span>
            <div class="bt-nodes">
              {#each (canEdit ? d.items : owned) as s (s.id)}
                {@const cur = current[s.id] ?? 0}
                {@const dr = draft[s.id] ?? 0}
                <div class="bt-node" class:has={cur > 0} class:staged={dr > cur}>
                  <span class="bt-name">{s.name}</span>
                  <div class="bt-pips">
                    {#each LEVELS as lv, i}
                      {@const rank = i + 1}
                      <button
                        type="button"
                        class="bt-pip"
                        class:on={rank <= cur}
                        class:stage={rank > cur && rank <= dr}
                        disabled={!canEdit}
                        title={canEdit ? $t(LEVEL_LABEL[lv]) : ''}
                        aria-label={$t(LEVEL_LABEL[lv])}
                        onclick={() => setRank(s.id, rank)}
                      ></button>
                    {/each}
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      {/each}
    </div>

    {#if canEdit}
      <div class="bt-bar">
        <span class="bt-muted">{changes.length ? $t('{n} change(s) staged', { n: changes.length }) : $t('Click ranks to stage badge raises.')}</span>
        {#if changes.length}
          <button type="button" class="bt-go" disabled={busy} onclick={submit}>
            {#if busy}<span class="spin"></span>{/if}{$t('Submit {n} for review', { n: changes.length })}
          </button>
          <button type="button" class="bt-ghost" disabled={busy} onclick={() => (draft = { ...current })}>{$t('Reset')}</button>
        {/if}
      </div>
    {/if}
  </div>
{/if}

<style>
  .bt { display: flex; flex-direction: column; gap: .8rem; }
  .bt-err { font-size: .82rem; color: var(--down); margin: 0; }
  .bt-ok { font-size: .82rem; color: var(--accent); margin: 0; }
  .bt-muted { font-size: .82rem; color: var(--muted); margin: 0; }
  .bt-domains { display: flex; flex-direction: column; gap: .8rem; }
  .bt-domain { display: flex; flex-direction: column; gap: .45rem; }
  .bt-dh { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .bt-nodes { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: .5rem; }
  .bt-node {
    display: flex; flex-direction: column; gap: .35rem; padding: .55rem .65rem;
    border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card-2);
  }
  .bt-node.has { border-color: color-mix(in srgb, var(--up) 40%, transparent); }
  .bt-node.staged { border-color: var(--accent); box-shadow: 0 0 0 1px var(--accent) inset; }
  .bt-name { font-size: .84rem; color: var(--text); font-weight: 500; line-height: 1.2; }
  .bt-pips { display: flex; gap: .3rem; }
  .bt-pip {
    width: 1.05rem; height: 1.05rem; border-radius: 4px; transform: rotate(45deg);
    border: 1.5px solid var(--border-2, var(--border)); background: transparent;
    padding: 0; cursor: pointer; transition: background .1s, border-color .1s;
  }
  .bt-pip:disabled { cursor: default; }
  .bt-pip.on { background: var(--up); border-color: var(--up); }
  .bt-pip.stage { background: var(--accent); border-color: var(--accent); opacity: .8; }
  .bt-pip:not(:disabled):hover { border-color: var(--accent); }
  .bt-bar { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; padding-top: .4rem; border-top: 1px solid var(--border); }
  .bt-go {
    display: inline-flex; align-items: center; gap: .4rem; padding: .45rem .85rem; border-radius: var(--r-sm);
    border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer;
  }
  .bt-go:disabled { opacity: .55; cursor: not-allowed; }
  .bt-ghost { padding: .45rem .8rem; border-radius: var(--r-sm); border: 1px solid var(--border); background: transparent; color: var(--text); font: inherit; cursor: pointer; }
</style>
