<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import InlineField from './InlineField.svelte';

  // Rich quick-view body for a chapter / working group: description, officers,
  // and its roster (chapter → member cards) or portfolio (WG → projects).
  // Officers / admins can edit the name & description in place (no forge — unit
  // metadata isn't value-minting); onChanged lets the parent refresh.
  let { unitId, kind, onChanged }: { unitId: string; kind: 'chapter' | 'working_group'; onChanged?: () => void } = $props();

  type Officer = { member_id: string; role: string | null; member: { full_name: string } | null };
  type Person = { id: string; full_name: string; affiliation: string | null };
  type Proj = { id: string; name: string; project_status: { name: string } | { name: string }[] | null };

  let unit = $state<{ id: string; name: string; description: string | null } | null>(null);
  let canEdit = $state(false);
  // forge a new member card (chapter officers / admins)
  let forgeOpen = $state(false);
  let fName = $state(''); let fEmail = $state('');
  let forgeBusy = $state(false); let forgeErr = $state(''); let forgeMsg = $state('');
  async function forgeMember() {
    if (!fName.trim() || !fEmail.trim()) { forgeErr = get(t)('Name and email are required.'); return; }
    forgeBusy = true; forgeErr = ''; forgeMsg = '';
    const { error: e } = await supabase.rpc('forge_member_card', { p_full_name: fName.trim(), p_email: fEmail.trim(), p_unit: unitId });
    forgeBusy = false;
    if (e) { forgeErr = e.message; return; }
    forgeMsg = get(t)('Card forged.'); fName = ''; fEmail = ''; forgeOpen = false;
    await load(); onChanged?.();
  }
  let officers = $state<Officer[]>([]);
  let members = $state<Person[]>([]);
  let projects = $state<Proj[]>([]);
  let loading = $state(true);

  async function rpcOrThrow(fn: string, args: Record<string, any>) {
    const { error: e } = await supabase.rpc(fn, args);
    if (e) throw new Error(e.message);
    await load(); onChanged?.();
  }
  const saveName = (v: string) => rpcOrThrow('unit_rename', { p_unit: unitId, p_name: v.trim() });
  const saveDesc = (v: string) => rpcOrThrow('unit_set_description', { p_unit: unitId, p_desc: v.trim() || null });

  function statusOf(p: Proj): string {
    const ps = p.project_status;
    return (Array.isArray(ps) ? ps[0]?.name : ps?.name) ?? '—';
  }

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; forgeOpen = false; forgeErr = ''; forgeMsg = '';
    const tasks: Promise<any>[] = [
      supabase.from('org_unit').select('id, name, description').eq('id', unitId).maybeSingle(),
      supabase.rpc('can_edit_unit', { p_unit: unitId }),
      supabase.from('org_unit_officer').select('member_id, role, member:member_id(full_name)').eq('org_unit_id', unitId)
    ];
    if (kind === 'chapter') {
      tasks.push(supabase.from('member').select('id, full_name, affiliation').eq('home_unit_id', unitId).order('full_name'));
    } else {
      tasks.push(supabase.from('project').select('id, name, project_status!project_status_id_fkey(name)').eq('org_unit_id', unitId).order('name'));
    }
    const [{ data: u }, { data: ce }, { data: off }, { data: rest }] = await Promise.all(tasks);
    unit = (u as any) ?? null;
    canEdit = ce === true;
    officers = (off as Officer[]) ?? [];
    if (kind === 'chapter') { members = (rest as Person[]) ?? []; projects = []; }
    else { projects = (rest as Proj[]) ?? []; members = []; }
    loading = false;
  }

  function roleLabel(r: string | null) {
    if (!r) return '';
    return r.charAt(0).toUpperCase() + r.slice(1);
  }

  let last = '';
  $effect(() => { if (unitId && unitId !== last) { last = unitId; load(); } });
</script>

{#if !loading}
  <div class="ud">
    <!-- name & description — inline-editable for officers / admins -->
    {#if canEdit}
      <div class="ud-edit">
        <InlineField label={$t('Name')} type="text" {canEdit} value={unit?.name ?? ''} onSave={saveName} />
        <InlineField label={$t('Description')} type="textarea" {canEdit}
          value={unit?.description ?? ''} placeholder={$t('What this unit is about…')} onSave={saveDesc} />
      </div>
    {/if}

    <!-- officers -->
    <div class="ud-sec">
      <span class="ud-h">{$t('Officers')}{#if officers.length}<span class="ud-ct"> · {officers.length}</span>{/if}</span>
      {#if officers.length === 0}
        <p class="ud-muted">{$t('No officers assigned.')}</p>
      {:else}
        <div class="ud-officers">
          {#each officers as o (o.member_id + (o.role ?? ''))}
            <a class="ud-officer" href={`/members/${o.member_id}`}>
              <span class="ud-name">{o.member?.full_name ?? '—'}</span>
              {#if o.role}<span class="badge dim">{$t(roleLabel(o.role))}</span>{/if}
            </a>
          {/each}
        </div>
      {/if}
    </div>

    <!-- roster (chapter) or portfolio (WG) — rows open the member / project page -->
    {#if kind === 'chapter'}
      <div class="ud-sec">
        <div class="ud-h-row">
          <span class="ud-h">{$t('Members')}{#if members.length}<span class="ud-ct"> · {members.length}</span>{/if}</span>
          {#if canEdit && !forgeOpen}
            <button type="button" class="ud-link" onclick={() => { forgeOpen = true; forgeErr = ''; forgeMsg = ''; }}>+ {$t('Add a member')}</button>
          {/if}
        </div>
        {#if forgeErr}<p class="ud-err">{forgeErr}</p>{/if}
        {#if forgeMsg}<p class="ud-ok">{forgeMsg}</p>{/if}
        {#if canEdit && forgeOpen}
          <div class="ud-forge">
            <input bind:value={fName} placeholder={$t('Full name')} />
            <input bind:value={fEmail} type="email" placeholder={$t('Email (to claim the card)')} />
            <div class="ud-forge-act">
              <button type="button" class="ud-go" disabled={forgeBusy} onclick={forgeMember}>{forgeBusy ? $t('Forging…') : $t('Forge card')}</button>
              <button type="button" class="ud-ghost" onclick={() => (forgeOpen = false)}>{$t('Cancel')}</button>
            </div>
          </div>
        {/if}
        {#if members.length === 0}
          <p class="ud-muted">{$t('No members yet.')}</p>
        {:else}
          <ul class="ud-list">
            {#each members as m (m.id)}
              <li><a class="ud-row" href={`/members/${m.id}`}>
                <span class="ud-name">{m.full_name}</span>
                {#if m.affiliation}<span class="ud-sub">{m.affiliation}</span>{/if}
              </a></li>
            {/each}
          </ul>
        {/if}
      </div>
    {:else}
      <div class="ud-sec">
        <span class="ud-h">{$t('Projects')}{#if projects.length}<span class="ud-ct"> · {projects.length}</span>{/if}</span>
        {#if projects.length === 0}
          <p class="ud-muted">{$t('No projects yet.')}</p>
        {:else}
          <ul class="ud-list">
            {#each projects as p (p.id)}
              <li><a class="ud-row" href={`/projects/${p.id}`}>
                <span class="ud-name">{p.name}</span>
                <span class="badge dim">{$t(statusOf(p))}</span>
              </a></li>
            {/each}
          </ul>
        {/if}
      </div>
    {/if}

  </div>
{/if}

<style>
  .ud { display: flex; flex-direction: column; gap: 1rem; }
  .ud-edit { display: flex; flex-direction: column; gap: .6rem; padding-bottom: .2rem; border-bottom: 1px solid var(--border); }
  .ud-h-row { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
  .ud-link { background: transparent; border: 0; color: var(--accent); font: inherit; font-size: .8rem; cursor: pointer; padding: 0; }
  .ud-link:hover { text-decoration: underline; }
  .ud-err { font-size: .78rem; color: var(--down); margin: 0; }
  .ud-ok { font-size: .78rem; color: var(--accent); margin: 0; }
  .ud-forge { display: flex; flex-direction: column; gap: .4rem; padding: .6rem .7rem; border: 1px solid var(--border); border-radius: var(--r-sm); background: var(--card-2); }
  .ud-forge input { padding: .45rem .55rem; border-radius: var(--r-sm); border: 1px solid var(--border-2); background: var(--card); color: var(--text); font-size: .88rem; }
  .ud-forge-act { display: flex; gap: .5rem; }
  .ud-go { padding: .45rem .8rem; border-radius: var(--r-sm); border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  .ud-go:disabled { opacity: .55; cursor: not-allowed; }
  .ud-ghost { padding: .45rem .8rem; border-radius: var(--r-sm); border: 1px solid var(--border); background: transparent; color: var(--text); font: inherit; cursor: pointer; }
  .ud-sec { display: flex; flex-direction: column; gap: .5rem; }
  .ud-h { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .ud-ct { color: var(--text-dim); }
  .ud-muted { font-size: .82rem; color: var(--muted); margin: 0; }
  .ud-officers { display: flex; flex-wrap: wrap; gap: .4rem; }
  .ud-officer { display: inline-flex; align-items: center; gap: .4rem; padding: .3rem .6rem; border: 1px solid var(--border); border-radius: var(--r-full); background: var(--card); text-decoration: none; color: inherit; }
  .ud-officer:hover { border-color: var(--accent); }
  .ud-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .3rem; }
  .ud-row { display: flex; align-items: center; justify-content: space-between; gap: .6rem; padding: .45rem .6rem; border: 1px solid var(--border); border-radius: var(--r-sm); background: var(--card); text-decoration: none; color: inherit; }
  .ud-row:hover { border-color: var(--accent); }
  .ud-name { font-size: .88rem; color: var(--text); font-weight: 500; }
  .ud-sub { font-size: .8rem; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
</style>
