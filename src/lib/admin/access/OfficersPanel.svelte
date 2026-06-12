<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import { get } from 'svelte/store';
  import { t } from '$lib/i18n';

  // Forge officers (operator member-cards) and place them in chapters / working
  // groups. An officer is the custodian role from the Phase-1 design: chapter
  // officers steward people, WG officers steward projects.
  type Unit = { id: string; code: string; name: string; kind: string; rank: number; description: string | null };
  type Officer = { org_unit_id: string; member_id: string; role: string; member: { full_name: string } | null };
  type Mem = { id: string; full_name: string };
  type Position = { id: string; name: string };
  type Pending = { id: string; full_name: string; email: string };

  let units = $state<Unit[]>([]);
  let officers = $state<Officer[]>([]);
  let operators = $state<Mem[]>([]);
  let positions = $state<Position[]>([]);
  let pending = $state<Pending[]>([]);
  let loading = $state(true);
  let error = $state(''); let notice = $state(''); let busy = $state('');

  // forge-officer form
  let fName = $state(''), fEmail = $state(''), fAffil = $state(''), fPos = $state(''), sending = $state(false);
  // inline email correction (fix a typo'd invite email that blocks login)
  let editEmailId = $state<string | null>(null);
  let emailDraft = $state('');
  async function saveEmail(id: string) {
    error = ''; notice = '';
    const { error: err } = await supabase.rpc('set_member_email', { p_member: id, p_email: emailDraft.trim() });
    if (err) { error = err.message; return; }
    editEmailId = null; notice = get(t)('Email updated.'); await load();
  }
  // per-unit assignment draft
  let dMember = $state<Record<string, string>>({});
  let dRole = $state<Record<string, string>>({});
  // new working group
  let wgName = $state(''), wgCode = $state(''), creating = $state(false);

  const ROLE_LABEL: Record<string, string> = { chair: 'Chair', secretary: 'Secretary', leader: 'Leader' };
  const rolesFor = (kind: string) => (kind === 'chapter' ? ['chair', 'secretary'] : ['leader']);
  const officersOf = (id: string) => officers.filter((o) => o.org_unit_id === id);
  const chapters = $derived(units.filter((u) => u.kind === 'chapter'));
  const wgs = $derived(units.filter((u) => u.kind === 'working_group'));

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; error = '';
    const [{ data: u }, { data: o }, { data: m }, { data: p }, { data: inv }] = await Promise.all([
      supabase.from('org_unit').select('id, code, name, kind, rank, description').order('rank'),
      supabase.from('org_unit_officer').select('org_unit_id, member_id, role, member:member_id(full_name)').is('ended_on', null),
      // assignable officers = active real members (not managed 'card' people).
      // (was kind='operator' — a kind nothing in the system ever creates, so the
      // dropdown was always empty; this matches the invited-members query below.)
      supabase.from('member').select('id, full_name').neq('kind', 'card').eq('status', 'active').order('full_name'),
      supabase.from('position').select('id, name').order('rank'),
      supabase.from('member').select('id, full_name, email').eq('status', 'invited').neq('kind', 'card').order('full_name')
    ]);
    units = (u as Unit[]) ?? []; officers = (o as Officer[]) ?? [];
    operators = (m as Mem[]) ?? []; positions = (p as Position[]) ?? []; pending = (inv as Pending[]) ?? [];
    loading = false;
  }
  onMount(load);

  async function forgeOfficer() {
    error = ''; notice = '';
    if (!fName.trim() || !fEmail.trim()) { error = get(t)('Name and email are required.'); return; }
    const email = fEmail.trim();
    sending = true;
    const { data, error: err } = await supabase.functions.invoke('invite-member', {
      body: { full_name: fName.trim(), email, affiliation: fAffil || null, position_id: fPos || null, inviter_name: get(member)?.full_name ?? null }
    });
    sending = false;
    if (err) { error = err.message; return; }
    if ((data as any)?.error) { error = (data as any).error; return; }
    notice = (data as any)?.email_sent === false
      ? get(t)('Officer added, but the invitation email could not be sent.')
      : get(t)('Invitation sent to {email} 🎉', { email });
    fName = ''; fEmail = ''; fAffil = ''; fPos = '';
    await load();
  }

  async function assign(unit: Unit) {
    error = '';
    const mid = dMember[unit.id]; const role = dRole[unit.id] || rolesFor(unit.kind)[0];
    if (!mid) return;
    busy = unit.id;
    const { error: err } = await supabase.rpc('assign_org_officer', { p_unit: unit.id, p_member: mid, p_role: role });
    busy = '';
    if (err) { error = err.message; return; }
    dMember[unit.id] = '';
    await load();
  }
  async function removeOfficer(o: Officer) {
    error = ''; busy = o.org_unit_id + o.member_id + o.role;
    const { error: err } = await supabase.rpc('remove_org_officer', { p_unit: o.org_unit_id, p_member: o.member_id, p_role: o.role });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
  async function createWG() {
    error = ''; notice = '';
    const name = wgName.trim(); const code = wgCode.trim().toUpperCase();
    if (!name || !code) { error = get(t)('Name and code are required.'); return; }
    const maxWg = Math.max(30, ...wgs.map((u) => u.rank));
    creating = true;
    const { error: err } = await supabase.from('org_unit').insert({ code, name, kind: 'working_group', rank: maxWg + 10 });
    creating = false;
    if (err) { error = (err as any).code === '23505' ? get(t)('That code is already taken.') : err.message; return; }
    notice = get(t)('Working group “{name}” created.', { name });
    wgName = ''; wgCode = '';
    await load();
  }
</script>

{#if error}<p class="err">{error}</p>{/if}
{#if notice}<p class="ok">{notice}</p>{/if}

<!-- forge an officer -->
<div class="card forge">
  <span class="sec">{$t('Invite an officer')}</span>
  <p class="muted hint">{$t('Send an email invitation to join the community. They bind to this record the first time they sign in.')}</p>
  <div class="forge-form">
    <label><span>{$t('Full name')}</span><input bind:value={fName} /></label>
    <label><span>{$t('Email')}</span><input type="email" bind:value={fEmail} /></label>
    <label><span>{$t('Affiliation')}</span><input bind:value={fAffil} /></label>
    <label><span>{$t('Position')}</span>
      <select bind:value={fPos}><option value="">{$t('— none —')}</option>{#each positions as p (p.id)}<option value={p.id}>{p.name}</option>{/each}</select>
    </label>
    <button class="go" onclick={forgeOfficer} disabled={sending}>{sending ? $t('Sending…') : $t('Invite')}</button>
  </div>
  {#if pending.length}
    <div class="pending">{$t('Pending')}:
      {#each pending as p (p.id)}
        {#if editEmailId === p.id}
          <span class="pchip edit">
            <input class="pmail-input" bind:value={emailDraft} placeholder="email" />
            <button class="pok" onclick={() => saveEmail(p.id)} title={$t('Save')}>✓</button>
            <button class="pno" onclick={() => (editEmailId = null)} title={$t('Cancel')}>✕</button>
          </span>
        {:else}
          <span class="pchip"><span class="pname">{p.full_name}</span><span class="pmail">{p.email}</span><button class="pedit" title={$t('Edit email')} onclick={() => { editEmailId = p.id; emailDraft = p.email; }}>✎</button></span>
        {/if}
      {/each}
    </div>
  {/if}
</div>

<!-- units + their officers -->
{#if loading}
  <p class="muted">{$t('Loading…')}</p>
{:else}
  {#each [{ label: 'Chapters', list: chapters }, { label: 'Working Groups', list: wgs }] as grp (grp.label)}
    <section>
      <span class="sec">{$t(grp.label)}</span>
      <div class="ulist">
        {#each grp.list as u (u.id)}
          <div class="unit">
            <div class="u-head"><span class="u-name">{u.name}</span><span class="u-code">{u.code}</span></div>
            <div class="u-officers">
              {#each officersOf(u.id) as o (o.member_id + o.role)}
                <span class="ochip">
                  <a href={`/members/${o.member_id}`}>{o.member?.full_name ?? '—'}</a>
                  <span class="orole">{$t(ROLE_LABEL[o.role] ?? o.role)}</span>
                  <button class="x" disabled={busy === o.org_unit_id + o.member_id + o.role} onclick={() => removeOfficer(o)} aria-label={$t('Remove')}>✕</button>
                </span>
              {/each}
              {#if !officersOf(u.id).length}<span class="muted none">{$t('No officers')}</span>{/if}
            </div>
            <div class="u-add">
              <select bind:value={dMember[u.id]}>
                <option value="">{$t('Add officer…')}</option>
                {#each operators as m (m.id)}<option value={m.id}>{m.full_name}</option>{/each}
              </select>
              <select bind:value={dRole[u.id]}>{#each rolesFor(u.kind) as r}<option value={r}>{$t(ROLE_LABEL[r])}</option>{/each}</select>
              <button class="add" disabled={busy === u.id || !dMember[u.id]} onclick={() => assign(u)}>+ {$t('Assign')}</button>
            </div>
          </div>
        {/each}
      </div>
    </section>
  {/each}

  <div class="card newwg">
    <span class="sec">{$t('New working group')}</span>
    <div class="forge-form">
      <label><span>{$t('Name')}</span><input bind:value={wgName} /></label>
      <label><span>{$t('Code')}</span><input bind:value={wgCode} style="max-width:8rem; text-transform:uppercase;" /></label>
      <button class="go" onclick={createWG} disabled={creating}>{creating ? $t('Creating…') : $t('Create')}</button>
    </div>
  </div>
{/if}

<style>
  .err { color: var(--down); font-size: .85rem; margin: 0; }
  .ok { color: var(--up); font-size: .85rem; margin: 0; }
  .sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .forge { display: flex; flex-direction: column; gap: .6rem; }
  .hint { margin: -.3rem 0 0; font-size: .8rem; }
  .forge-form { display: flex; flex-wrap: wrap; gap: .6rem; align-items: flex-end; }
  .forge-form label { display: flex; flex-direction: column; gap: .2rem; flex: 1; min-width: 140px; }
  .forge-form label span { font-size: .75rem; color: var(--muted); }
  .go { padding: .5rem .9rem; border-radius: var(--r-sm); border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  .go:disabled { opacity: .55; cursor: not-allowed; }
  .pending { font-size: .8rem; color: var(--muted); display: flex; flex-wrap: wrap; gap: .35rem; align-items: center; }
  .pchip { display: inline-flex; align-items: center; gap: .35rem; border: 1px dashed var(--border-2); border-radius: var(--r-full); padding: .15rem .5rem; }
  .pname { color: var(--text); }
  .pmail { color: var(--muted); font-size: .74rem; }
  .pedit, .pok, .pno { background: transparent; border: 0; cursor: pointer; font: inherit; color: var(--muted); padding: 0 .15rem; }
  .pedit:hover, .pok:hover { color: var(--accent); }
  .pno:hover { color: var(--down); }
  .pmail-input { padding: .15rem .35rem; border-radius: var(--r-sm); border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .78rem; min-width: 16rem; }
  .pchip { padding: .1rem .5rem; border: 1px dashed var(--border-2); border-radius: var(--r-full); color: var(--text-dim); }
  .ulist { display: flex; flex-direction: column; gap: .5rem; margin-top: .4rem; }
  .unit { border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card); padding: .7rem .9rem; display: flex; flex-direction: column; gap: .5rem; }
  .u-head { display: flex; align-items: baseline; gap: .5rem; }
  .u-name { font-weight: 600; color: var(--text); }
  .u-code { font-size: .76rem; color: var(--muted); }
  .u-officers { display: flex; flex-wrap: wrap; gap: .4rem; }
  .ochip { display: inline-flex; align-items: center; gap: .35rem; padding: .2rem .25rem .2rem .6rem; border: 1px solid var(--border); border-radius: var(--r-full); background: var(--card-2); font-size: .82rem; }
  .ochip a { color: var(--text); text-decoration: none; font-weight: 500; }
  .ochip a:hover { color: var(--accent); }
  .orole { color: var(--warn, var(--accent)); font-size: .72rem; }
  .x { border: 0; background: transparent; color: var(--muted); cursor: pointer; font-size: .8rem; padding: 0 .2rem; border-radius: 50%; }
  .x:hover { color: var(--down); filter: none; }
  .none { font-size: .8rem; }
  .u-add { display: flex; flex-wrap: wrap; gap: .4rem; }
  .u-add select { padding: .35rem .5rem; border-radius: var(--r-sm); border: 1px solid var(--border-2); background: var(--card); color: var(--text); font-size: .85rem; }
  .add { padding: .35rem .7rem; border-radius: var(--r-sm); border: 1px solid var(--border-2); background: transparent; color: var(--accent); font: inherit; font-size: .85rem; cursor: pointer; }
  .add:disabled { opacity: .5; cursor: not-allowed; }
  .add:hover:not(:disabled) { border-color: var(--accent); }
  .newwg { display: flex; flex-direction: column; gap: .6rem; }
</style>
