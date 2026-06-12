<script lang="ts">
  // The living-record task board (BUILD PLAN P0). Inline-editable
  // Task · Type · Owner · Status · Note, optionally grouped (coverage).
  // Optimistic: every edit applies locally first, then reconciles via RPC;
  // on failure it reverts and shows the reason inline (no reload-everything).
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  let { projectId, canEdit = false, onChanged }: {
    projectId: string;
    canEdit?: boolean;
    onChanged?: () => void;
  } = $props();

  type Task = {
    id: string; project_id: string; grp: string | null; name: string;
    skill_id: string | null; owner_member_id: string | null;
    state: string; note: string | null; sort: number;
  };
  type Member = { id: string; full_name: string; kind: string };
  type Skill = { id: string; name: string };

  const TASK_STATES = ['open', 'doing', 'done'];
  const COVERAGE_STATES = ['potential', 'checking', 'confirmed'];
  const STATE_LABEL: Record<string, string> = {
    open: 'Open', doing: 'Doing', done: 'Done',
    potential: 'Potential', checking: 'Checking', confirmed: 'Confirmed'
  };

  let tasks = $state<Task[]>([]);
  let members = $state<Member[]>([]);
  let skills = $state<Skill[]>([]);
  let loading = $state(true);
  let err = $state('');
  let busy = $state<string | null>(null);     // task id mid-write
  let adding = $state<string | null>(null);    // group key being added to ('' = ungrouped)
  let newName = $state('');

  const skillName = (id: string | null) => id ? (skills.find(s => s.id === id)?.name ?? '') : '';
  const memberName = (id: string | null) => id ? (members.find(m => m.id === id)?.full_name ?? '?') : '';
  const statesFor = (tk: Task) => (tk.grp ? COVERAGE_STATES : TASK_STATES);

  // group tasks: ungrouped first, then named groups, each sorted by `sort`
  const groups = $derived.by(() => {
    const by = new Map<string, Task[]>();
    for (const tk of [...tasks].sort((a, b) => a.sort - b.sort)) {
      const k = tk.grp ?? '';
      if (!by.has(k)) by.set(k, []);
      by.get(k)!.push(tk);
    }
    return [...by.entries()].sort((a, b) => (a[0] === '' ? -1 : b[0] === '' ? 1 : a[0].localeCompare(b[0])));
  });

  async function load() {
    if (!supabaseConfigured || !projectId) { loading = false; return; }
    loading = true; err = '';
    const [tk, mem, sk] = await Promise.all([
      supabase.from('task').select('id,project_id,grp,name,skill_id,owner_member_id,state,note,sort').eq('project_id', projectId),
      supabase.from('member').select('id,full_name,kind').order('full_name'),
      supabase.from('skill').select('id,name,parent_id')
    ]);
    if (tk.error) err = tk.error.message;
    tasks = (tk.data as Task[]) ?? [];
    members = (mem.data as Member[]) ?? [];
    // leaf skills only (have a parent, are nobody's parent) = the work-type vocabulary
    const rows = (sk.data as any[]) ?? [];
    const parents = new Set(rows.map(r => r.parent_id).filter(Boolean));
    skills = rows.filter(r => r.parent_id && !parents.has(r.id)).map(r => ({ id: r.id, name: r.name }));
    loading = false;
  }
  $effect(() => { projectId; load(); });

  // --- optimistic patch: mutate locally, reconcile, revert on error ---
  async function patch(tk: Task, p: Record<string, unknown>) {
    const before = { ...tk };
    Object.assign(tk, p);                          // optimistic
    tasks = tasks;
    busy = tk.id; err = '';
    const { data, error } = await supabase.rpc('task_update', { p_task: tk.id, p_patch: p });
    busy = null;
    if (error) { Object.assign(tk, before); tasks = tasks; err = error.message; return; }
    if (data) { const i = tasks.findIndex(x => x.id === tk.id); if (i >= 0) tasks[i] = data as Task; tasks = tasks; }
    onChanged?.();
  }

  async function addTask(grp: string) {
    const name = newName.trim();
    if (!name) return;
    busy = 'add'; err = '';
    const { data, error } = await supabase.rpc('task_add', {
      p_project: projectId, p_name: name, p_grp: grp || null
    });
    busy = null;
    if (error) { err = error.message; return; }
    if (data) tasks = [...tasks, data as Task];
    newName = ''; adding = null;
    onChanged?.();
  }

  async function remove(tk: Task) {
    const keep = tasks;
    tasks = tasks.filter(x => x.id !== tk.id);      // optimistic
    busy = tk.id; err = '';
    const { error } = await supabase.rpc('task_remove', { p_task: tk.id });
    busy = null;
    if (error) { tasks = keep; err = error.message; return; }
    onChanged?.();
  }
</script>

<section class="tb">
  <div class="tb-head">
    <h3>{$t('Tasks')}</h3>
    {#if err}<span class="tb-err">{err}</span>{/if}
  </div>

  {#if loading}
    <p class="tb-dim">{$t('Loading…')}</p>
  {:else if !tasks.length && !canEdit}
    <p class="tb-dim">{$t('No tasks yet.')}</p>
  {:else}
    {#each groups as [grp, rows] (grp)}
      {#if grp}<div class="tb-grp">{grp}</div>{/if}
      <table class="tb-table">
        <thead>
          <tr><th>{$t('Task')}</th><th>{$t('Type')}</th><th>{$t('Owner')}</th><th>{$t('Status')}</th><th>{$t('Note')}</th>{#if canEdit}<th></th>{/if}</tr>
        </thead>
        <tbody>
          {#each rows as tk (tk.id)}
            <tr class:busy={busy === tk.id}>
              <td>
                {#if canEdit}
                  <input class="cell" value={tk.name} onchange={(e) => patch(tk, { name: (e.target as HTMLInputElement).value })} />
                {:else}{tk.name}{/if}
              </td>
              <td>
                {#if canEdit}
                  <select class="cell" value={tk.skill_id ?? ''} onchange={(e) => patch(tk, { skill_id: (e.target as HTMLSelectElement).value || null })}>
                    <option value="">{$t('—')}</option>
                    {#each skills as s}<option value={s.id}>{s.name}</option>{/each}
                  </select>
                {:else}{skillName(tk.skill_id)}{/if}
              </td>
              <td>
                {#if canEdit}
                  <select class="cell" value={tk.owner_member_id ?? ''} onchange={(e) => patch(tk, { owner_member_id: (e.target as HTMLSelectElement).value || null })}>
                    <option value="">{$t('TBD')}</option>
                    {#each members as m}<option value={m.id}>{m.full_name}</option>{/each}
                  </select>
                {:else}<span class:tb-tbd={!tk.owner_member_id}>{tk.owner_member_id ? memberName(tk.owner_member_id) : $t('TBD')}</span>{/if}
              </td>
              <td>
                {#if canEdit}
                  <select class="cell st-{tk.state}" value={tk.state} onchange={(e) => patch(tk, { state: (e.target as HTMLSelectElement).value })}>
                    {#each statesFor(tk) as s}<option value={s}>{$t(STATE_LABEL[s])}</option>{/each}
                  </select>
                {:else}<span class="pill st-{tk.state}">{$t(STATE_LABEL[tk.state] ?? tk.state)}</span>{/if}
              </td>
              <td>
                {#if canEdit}
                  <input class="cell" value={tk.note ?? ''} placeholder={$t('—')} onchange={(e) => patch(tk, { note: (e.target as HTMLInputElement).value })} />
                {:else}{tk.note ?? ''}{/if}
              </td>
              {#if canEdit}<td><button class="tb-x" title={$t('Remove')} onclick={() => remove(tk)}>✕</button></td>{/if}
            </tr>
          {/each}
        </tbody>
      </table>

      {#if canEdit}
        {#if adding === grp}
          <div class="tb-add">
            <input class="cell" placeholder={$t('Task name')} bind:value={newName}
              onkeydown={(e) => e.key === 'Enter' && addTask(grp)} />
            <button class="tb-go" disabled={busy === 'add' || !newName.trim()} onclick={() => addTask(grp)}>{$t('Add')}</button>
            <button class="tb-ghost" onclick={() => { adding = null; newName = ''; }}>{$t('Cancel')}</button>
          </div>
        {:else}
          <button class="tb-addrow" onclick={() => { adding = grp; newName = ''; }}>＋ {$t('Add task')}</button>
        {/if}
      {/if}
    {/each}

    {#if canEdit && !groups.length}
      <button class="tb-addrow" onclick={() => { adding = ''; newName = ''; }}>＋ {$t('Add task')}</button>
      {#if adding === ''}
        <div class="tb-add">
          <input class="cell" placeholder={$t('Task name')} bind:value={newName}
            onkeydown={(e) => e.key === 'Enter' && addTask('')} />
          <button class="tb-go" disabled={busy === 'add' || !newName.trim()} onclick={() => addTask('')}>{$t('Add')}</button>
        </div>
      {/if}
    {/if}
  {/if}
</section>

<style>
  .tb { margin: 1rem 0; }
  .tb-head { display: flex; align-items: baseline; gap: .75rem; margin-bottom: .5rem; }
  .tb-head h3 { margin: 0; font-size: 1rem; }
  .tb-err { color: var(--neg, #c0392b); font-size: .82rem; }
  .tb-dim { color: var(--muted, #888); font-size: .9rem; }
  .tb-grp { font-weight: 600; font-size: .85rem; margin: .75rem 0 .25rem; color: var(--muted, #777); }
  .tb-table { width: 100%; border-collapse: collapse; font-size: .88rem; }
  .tb-table th { text-align: left; font-weight: 500; color: var(--muted, #999); padding: .25rem .4rem; border-bottom: 1px solid var(--line, #eee); font-size: .78rem; }
  .tb-table td { padding: .15rem .4rem; border-bottom: 1px solid var(--line, #f3f3f3); vertical-align: middle; }
  tr.busy { opacity: .55; }
  .cell { width: 100%; border: 1px solid transparent; background: transparent; padding: .25rem .35rem; border-radius: var(--r-sm); font: inherit; color: inherit; }
  .cell:hover { border-color: var(--line, #e6e6e6); }
  .cell:focus { border-color: var(--accent, #6a7cff); outline: none; background: var(--card, #fff); }
  .pill { font-size: .76rem; padding: .1rem .5rem; border-radius: var(--r-full); border: 1px solid var(--line, #ddd); }
  .st-done, select.st-done { color: #2e7d4f; }
  .st-doing, select.st-doing { color: #b8860b; }
  .st-confirmed { color: #2e7d4f; }
  .tb-tbd { color: var(--muted, #aaa); font-style: italic; }
  .tb-x { border: none; background: none; cursor: pointer; color: var(--muted, #bbb); }
  .tb-x:hover { color: var(--neg, #c0392b); }
  .tb-add { display: flex; gap: .4rem; margin: .35rem 0; }
  .tb-addrow { border: 1px dashed var(--line, #ddd); background: none; border-radius: var(--r-sm); padding: .35rem .6rem; cursor: pointer; color: var(--muted, #777); font-size: .85rem; margin-top: .35rem; }
  .tb-addrow:hover { border-color: var(--accent, #6a7cff); color: var(--accent, #6a7cff); }
  .tb-go { border: none; background: var(--accent, #6a7cff); color: #fff; border-radius: var(--r-sm); padding: .35rem .8rem; cursor: pointer; }
  .tb-go:disabled { opacity: .5; cursor: default; }
  .tb-ghost { border: 1px solid var(--line, #ddd); background: none; border-radius: var(--r-sm); padding: .35rem .7rem; cursor: pointer; }
</style>
