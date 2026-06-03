<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities } from '$lib/session';
  import { t } from '$lib/i18n';

  type Unit = { id: string; code: string; name: string; kind: string; rank: number };
  type Officer = { org_unit_id: string; member_id: string; role: string; member: { full_name: string } | null };
  type Mem = { id: string; full_name: string };

  let units = $state<Unit[]>([]);
  let officers = $state<Officer[]>([]);
  let members = $state<Mem[]>([]);
  let loading = $state(true);
  let error = $state('');
  let busy = $state('');

  // per-unit draft selections: unitId -> { member, role }
  let draftMember = $state<Record<string, string>>({});
  let draftRole = $state<Record<string, string>>({});

  // new working-group form
  let wgName = $state('');
  let wgCode = $state('');
  let wgDesc = $state('');
  let creating = $state(false);
  let notice = $state('');

  const canManage = $derived($capabilities.has('manage_members'));
  const ROLE_LABEL: Record<string, string> = { chair: 'Chair', secretary: 'Secretary', leader: 'Leader' };
  function rolesFor(kind: string) {
    return kind === 'chapter' ? ['chair', 'secretary'] : ['leader'];
  }
  function officersOf(unitId: string) {
    return officers.filter((o) => o.org_unit_id === unitId);
  }

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: u }, { data: o }, { data: m, error: err }] = await Promise.all([
      supabase.from('org_unit').select('id, code, name, kind, rank').order('rank'),
      supabase.from('org_unit_officer').select('org_unit_id, member_id, role, member:member_id(full_name)').is('ended_on', null),
      supabase.from('member').select('id, full_name').eq('kind', 'operator').eq('status', 'active').order('full_name')
    ]);
    if (err) error = err.message;
    units = (u as Unit[]) ?? [];
    officers = (o as Officer[]) ?? [];
    members = (m as Mem[]) ?? [];
    loading = false;
  }
  onMount(load);

  async function createWG() {
    error = ''; notice = '';
    const name = wgName.trim();
    const code = wgCode.trim().toUpperCase();
    if (!name || !code) { error = $t('Name and code are required.'); return; }
    // place it after the last working group in the ordering
    const maxWgRank = Math.max(30, ...units.filter((u) => u.kind === 'working_group').map((u) => u.rank));
    creating = true;
    const { error: err } = await supabase.from('org_unit').insert({
      code, name, kind: 'working_group', rank: maxWgRank + 10,
      description: wgDesc.trim() || null
    });
    creating = false;
    if (err) {
      error = (err as any).code === '23505' ? $t('That code is already taken.') : err.message;
      return;
    }
    notice = $t('Working group “{name}” created.', { name });
    wgName = ''; wgCode = ''; wgDesc = '';
    await load();
  }

  async function assign(unit: Unit) {
    error = '';
    const mid = draftMember[unit.id];
    const role = draftRole[unit.id] || rolesFor(unit.kind)[0];
    if (!mid) return;
    busy = unit.id;
    const { error: err } = await supabase.rpc('assign_org_officer', { p_unit: unit.id, p_member: mid, p_role: role });
    busy = '';
    if (err) { error = err.message; return; }
    draftMember[unit.id] = '';
    await load();
  }

  async function remove(o: Officer) {
    error = '';
    busy = o.org_unit_id + o.member_id + o.role;
    const { error: err } = await supabase.rpc('remove_org_officer', { p_unit: o.org_unit_id, p_member: o.member_id, p_role: o.role });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
</script>

<div class="stack">
  <h1>{$t('Chapters & Working Groups')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('Assign officers to each unit. Chapters carry a Chair and Secretary (who manage their members and act for member-cards); working groups carry a Leader.')}
  </p>

  {#if !canManage}
    <p class="banner">{$t('You need the manage_members capability to assign officers.')}</p>
  {/if}
  {#if error}<p style="color:var(--down);">{error}</p>{/if}
  {#if notice}<p style="color:var(--up);">{notice}</p>{/if}

  {#if canManage}
    <div class="card stack" style="gap:.6rem;">
      <h2 style="margin:0; font-size:1rem;">{$t('New working group')}</h2>
      <p class="muted" style="font-size:.82rem; margin:0;">
        {$t('Spin up a new working group. Give it a short code and a name, then assign a Leader below.')}
      </p>
      <div class="row" style="align-items:flex-end; flex-wrap:wrap; gap:.5rem;">
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Code')}</span>
          <input bind:value={wgCode} placeholder="e.g. NLP" style="max-width:130px; text-transform:uppercase;" /></label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Name')}</span>
          <input bind:value={wgName} placeholder={$t('Working group name')} style="min-width:220px;" /></label>
        <label class="stack" style="gap:.2rem; flex:1; min-width:220px;"><span class="muted" style="font-size:.72rem;">{$t('Description')} <span style="opacity:.6;">({$t('optional')})</span></span>
          <input bind:value={wgDesc} placeholder={$t('What this unit is about…')} /></label>
        <button disabled={!wgName.trim() || !wgCode.trim() || creating} onclick={createWG}>
          {creating ? $t('Creating…') : $t('Create working group')}</button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else}
    {#each units as u}
      <div class="card stack" style="gap:.6rem;">
        <div class="row" style="justify-content:space-between; align-items:center;">
          <div>
            <strong>{u.name}</strong>
            <span class="badge dim" style="margin-left:.4rem; font-size:.7rem;">{u.code}</span>
            <span class="badge {u.kind === 'chapter' ? 'pos' : 'warn'}" style="margin-left:.3rem; font-size:.7rem;">
              {u.kind === 'chapter' ? $t('Chapter') : $t('Working group')}
            </span>
          </div>
        </div>

        {#if officersOf(u.id).length === 0}
          <p class="muted" style="margin:0; font-size:.85rem;">{$t('No officers yet.')}</p>
        {:else}
          <ul style="margin:0; padding:0; list-style:none;">
            {#each officersOf(u.id) as o}
              <li class="row" style="justify-content:space-between; align-items:center; max-width:480px; padding:.2rem 0;">
                <span>{o.member?.full_name ?? '—'} <span class="badge dim" style="font-size:.7rem;">{$t(ROLE_LABEL[o.role])}</span></span>
                {#if canManage}
                  <button class="danger" disabled={busy === o.org_unit_id + o.member_id + o.role} onclick={() => remove(o)}>{$t('Remove')}</button>
                {/if}
              </li>
            {/each}
          </ul>
        {/if}

        {#if canManage}
          <div class="row" style="align-items:flex-end; flex-wrap:wrap; gap:.5rem; border-top:1px dashed var(--border); padding-top:.6rem;">
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Member')}</span>
              <select bind:value={draftMember[u.id]} style="max-width:220px;">
                <option value="">—</option>
                {#each members as m}<option value={m.id}>{m.full_name}</option>{/each}
              </select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Role')}</span>
              <select bind:value={draftRole[u.id]}>
                {#each rolesFor(u.kind) as r}<option value={r}>{$t(ROLE_LABEL[r])}</option>{/each}
              </select>
            </label>
            <button disabled={!draftMember[u.id] || busy === u.id} onclick={() => assign(u)}>{$t('Assign')}</button>
          </div>
        {/if}
      </div>
    {/each}
  {/if}
</div>
