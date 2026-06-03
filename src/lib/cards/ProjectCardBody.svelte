<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  // The editable project card: media links (many), free-form history, and the
  // editable core fields (name / summary / venue / working group). All writes
  // go through the project_* RPCs, which enforce leader / WG-officer / admin
  // and auto-log each change to history. Read-only when the viewer can't edit.
  let { projectId, venues = [], workingGroups = [], onChanged }: {
    projectId: string;
    venues?: { id: string; name: string; kind: string; deadline: string | null }[];
    workingGroups?: { id: string; name: string }[];
    onChanged?: () => void;
  } = $props();

  type Link = { id: string; kind: string; title: string | null; url: string; notes: string | null; created_at: string; member: { full_name: string } | null };
  type Meeting = { id: string; title: string; scheduled_at: string; ends_at: string | null; location: string | null; agenda: string | null; recurrence: string; member: { full_name: string } | null };
  type Event = { id: string; event_type: string; summary: string; created_at: string; member: { full_name: string } | null };
  type Proj = { id: string; name: string; summary: string | null; venue_id: string | null; org_unit_id: string | null };

  const LINK_KINDS = ['proposal', 'overleaf', 'openreview', 'paper', 'repo', 'dataset', 'slides', 'drive', 'media', 'other'];
  const KIND_ICON: Record<string, string> = {
    proposal: '📄', overleaf: '✍', openreview: '🔎', paper: '📑', repo: '💻',
    dataset: '🗃', slides: '📊', drive: '📁', media: '🎞', other: '🔗'
  };

  let canEdit = $state(false);
  let proj = $state<Proj | null>(null);
  let links = $state<Link[]>([]);
  let meetings = $state<Meeting[]>([]);
  let events = $state<Event[]>([]);
  let loading = $state(true);
  let busy = $state(''); let err = $state('');

  // edit-details form
  let editing = $state(false);
  let fName = $state(''); let fSummary = $state(''); let fVenue = $state(''); let fUnit = $state('');
  // add-link form
  let lKind = $state('paper'); let lTitle = $state(''); let lUrl = $state(''); let lNotes = $state('');
  let showAddLink = $state(false);
  // note box
  let note = $state('');
  // add-meeting form
  let showAddMeeting = $state(false);
  let mTitle = $state(''); let mAt = $state(''); let mEnds = $state(''); let mLoc = $state(''); let mAgenda = $state(''); let mRecur = $state('none');
  const RECUR = ['none', 'weekly', 'biweekly', 'monthly'];
  const RECUR_LABEL: Record<string, string> = { none: 'One-off', weekly: 'Weekly', biweekly: 'Biweekly', monthly: 'Monthly' };

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; err = '';
    const [{ data: p }, { data: ce }, { data: lk }, { data: mt }, { data: ev }] = await Promise.all([
      supabase.from('project').select('id, name, summary, venue_id, org_unit_id').eq('id', projectId).maybeSingle(),
      supabase.rpc('can_edit_project', { p_project: projectId }),
      supabase.from('project_link').select('id, kind, title, url, notes, created_at, member:added_by(full_name)').eq('project_id', projectId).order('created_at', { ascending: false }),
      supabase.from('project_meeting').select('id, title, scheduled_at, ends_at, location, agenda, recurrence, member:created_by(full_name)').eq('project_id', projectId).order('scheduled_at', { ascending: false }),
      supabase.from('project_event').select('id, event_type, summary, created_at, member:actor_member_id(full_name)').eq('project_id', projectId).order('created_at', { ascending: false }).limit(40)
    ]);
    proj = (p as Proj) ?? null;
    canEdit = ce === true;
    links = (lk as Link[]) ?? [];
    meetings = (mt as Meeting[]) ?? [];
    events = (ev as Event[]) ?? [];
    loading = false;
  }

  function openEdit() {
    if (!proj) return;
    fName = proj.name; fSummary = proj.summary ?? '';
    fVenue = proj.venue_id ?? ''; fUnit = proj.org_unit_id ?? '';
    editing = true; err = '';
  }

  async function saveDetails() {
    if (!proj) return;
    busy = 'edit'; err = '';
    try {
      if (fName.trim() && fName.trim() !== proj.name) {
        const { error: e } = await supabase.rpc('project_rename', { p_project: projectId, p_name: fName.trim() });
        if (e) throw e;
      }
      if ((fSummary.trim() || null) !== (proj.summary ?? null)) {
        const { error: e } = await supabase.rpc('project_set_summary', { p_project: projectId, p_summary: fSummary.trim() || null });
        if (e) throw e;
      }
      if ((fVenue || null) !== (proj.venue_id ?? null)) {
        const { error: e } = await supabase.rpc('project_set_venue', { p_project: projectId, p_venue: fVenue || null });
        if (e) throw e;
      }
      if ((fUnit || null) !== (proj.org_unit_id ?? null)) {
        const { error: e } = await supabase.rpc('project_set_org_unit', { p_project: projectId, p_unit: fUnit || null });
        if (e) throw e;
      }
    } catch (e: any) { busy = ''; err = e.message ?? String(e); return; }
    busy = ''; editing = false;
    await load(); onChanged?.();
  }

  async function addLink() {
    if (!lUrl.trim()) { err = get(t)('A URL is required.'); return; }
    busy = 'link'; err = '';
    const { error: e } = await supabase.rpc('project_link_add', {
      p_project: projectId, p_kind: lKind, p_title: lTitle.trim() || null, p_url: lUrl.trim(), p_notes: lNotes.trim() || null
    });
    busy = '';
    if (e) { err = e.message; return; }
    lTitle = ''; lUrl = ''; lNotes = ''; lKind = 'paper'; showAddLink = false;
    await load();
  }

  async function removeLink(id: string) {
    busy = id; err = '';
    const { error: e } = await supabase.rpc('project_link_remove', { p_link: id });
    busy = '';
    if (e) { err = e.message; return; }
    await load();
  }

  async function postNote() {
    if (!note.trim()) return;
    busy = 'note'; err = '';
    const { error: e } = await supabase.rpc('project_note', { p_project: projectId, p_text: note.trim() });
    busy = '';
    if (e) { err = e.message; return; }
    note = ''; await load();
  }

  async function addMeeting() {
    if (!mTitle.trim() || !mAt) { err = get(t)('Meeting title and time are required.'); return; }
    busy = 'meeting'; err = '';
    const { error: e } = await supabase.rpc('project_meeting_add', {
      p_project: projectId, p_title: mTitle.trim(),
      p_scheduled_at: new Date(mAt).toISOString(),
      p_ends_at: mEnds ? new Date(mEnds).toISOString() : null,
      p_location: mLoc.trim() || null, p_agenda: mAgenda.trim() || null, p_recurrence: mRecur
    });
    busy = '';
    if (e) { err = e.message; return; }
    mTitle = ''; mAt = ''; mEnds = ''; mLoc = ''; mAgenda = ''; mRecur = 'none'; showAddMeeting = false;
    await load();
  }

  async function removeMeeting(id: string) {
    busy = id; err = '';
    const { error: e } = await supabase.rpc('project_meeting_remove', { p_meeting: id });
    busy = '';
    if (e) { err = e.message; return; }
    await load();
  }

  function fmtWhen(iso: string, ends: string | null) {
    const d = new Date(iso);
    const day = d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
    const time = d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
    const endTime = ends ? new Date(ends).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' }) : '';
    return `${day} · ${time}${endTime ? '–' + endTime : ''}`;
  }
  const isPast = (iso: string) => new Date(iso).getTime() < Date.now();

  function host(u: string) { try { return new URL(u).host.replace(/^www\./, ''); } catch { return u; } }
  function rel(iso: string) {
    const d = Math.round((Date.now() - new Date(iso).getTime()) / 86400000);
    if (d <= 0) return get(t)('today');
    if (d === 1) return get(t)('yesterday');
    if (d < 30) return get(t)('{d}d ago', { d });
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }

  const venueName = $derived((id: string | null) => venues.find((v) => v.id === id)?.name ?? '');

  let last = '';
  $effect(() => { if (projectId && projectId !== last) { last = projectId; load(); } });
</script>

{#if !loading}
  {#if err}<p class="pcb-err">{err}</p>{/if}

  <!-- editable core fields -->
  {#if canEdit}
    <div class="pcb-section">
      <div class="pcb-h-row">
        <span class="pcb-h">{$t('Details')}</span>
        {#if !editing}<button type="button" class="pcb-link" onclick={openEdit}>✎ {$t('Edit')}</button>{/if}
      </div>
      {#if editing}
        <div class="pcb-form">
          <label class="pcb-field"><span>{$t('Name')}</span><input bind:value={fName} /></label>
          <label class="pcb-field"><span>{$t('Summary')}</span><textarea rows="2" bind:value={fSummary}></textarea></label>
          <label class="pcb-field"><span>{$t('Target venue')}</span>
            <select bind:value={fVenue}>
              <option value="">{$t('— none —')}</option>
              {#each venues as v}<option value={v.id}>{v.name}</option>{/each}
            </select>
          </label>
          <label class="pcb-field"><span>{$t('Working Group')}</span>
            <select bind:value={fUnit}>
              <option value="">{$t('— unattributed —')}</option>
              {#each workingGroups as w}<option value={w.id}>{w.name}</option>{/each}
            </select>
          </label>
          <div class="pcb-actions">
            <button type="button" class="pcb-go" disabled={busy === 'edit'} onclick={saveDetails}>
              {#if busy === 'edit'}<span class="spin"></span>{/if}{$t('Save')}
            </button>
            <button type="button" class="pcb-ghost" onclick={() => (editing = false)}>{$t('Cancel')}</button>
          </div>
        </div>
      {/if}
    </div>
  {/if}

  <!-- media links -->
  <div class="pcb-section">
    <div class="pcb-h-row">
      <span class="pcb-h">{$t('Media & links')}{#if links.length}<span class="pcb-ct"> · {links.length}</span>{/if}</span>
      {#if canEdit}<button type="button" class="pcb-link" onclick={() => (showAddLink = !showAddLink)}>{showAddLink ? $t('Cancel') : '+ ' + $t('Add link')}</button>{/if}
    </div>

    {#if showAddLink && canEdit}
      <div class="pcb-form">
        <div class="pcb-row">
          <label class="pcb-field" style="flex:0 0 9rem;"><span>{$t('Kind')}</span>
            <select bind:value={lKind}>{#each LINK_KINDS as k}<option value={k}>{KIND_ICON[k]} {$t(k)}</option>{/each}</select>
          </label>
          <label class="pcb-field" style="flex:1;"><span>{$t('Title')}</span><input bind:value={lTitle} placeholder={$t('optional')} /></label>
        </div>
        <label class="pcb-field"><span>{$t('URL')}</span><input bind:value={lUrl} placeholder="https://…" /></label>
        <label class="pcb-field"><span>{$t('Notes')}</span><input bind:value={lNotes} placeholder={$t('optional')} /></label>
        <button type="button" class="pcb-go" disabled={busy === 'link'} onclick={addLink}>
          {#if busy === 'link'}<span class="spin"></span>{/if}{$t('Add link')}
        </button>
      </div>
    {/if}

    {#if links.length === 0}
      <p class="pcb-muted">{$t('No links yet.')}</p>
    {:else}
      <ul class="pcb-links">
        {#each links as l (l.id)}
          <li class="pcb-link-row">
            <span class="pcb-kind" title={$t(l.kind)}>{KIND_ICON[l.kind] ?? '🔗'}</span>
            <a class="pcb-link-main" href={l.url} target="_blank" rel="noopener noreferrer">
              <span class="pcb-link-title">{l.title || host(l.url)}</span>
              <span class="pcb-link-host">{host(l.url)}{#if l.notes} · {l.notes}{/if}</span>
            </a>
            {#if canEdit}
              <button type="button" class="pcb-x" disabled={busy === l.id} title={$t('Remove')} aria-label={$t('Remove')} onclick={() => removeLink(l.id)}>✕</button>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </div>

  <!-- meetings -->
  <div class="pcb-section">
    <div class="pcb-h-row">
      <span class="pcb-h">{$t('Meetings')}{#if meetings.length}<span class="pcb-ct"> · {meetings.length}</span>{/if}</span>
      {#if canEdit}<button type="button" class="pcb-link" onclick={() => (showAddMeeting = !showAddMeeting)}>{showAddMeeting ? $t('Cancel') : '+ ' + $t('Schedule meeting')}</button>{/if}
    </div>

    {#if showAddMeeting && canEdit}
      <div class="pcb-form">
        <label class="pcb-field"><span>{$t('Title')}</span><input bind:value={mTitle} placeholder={$t('Kickoff, weekly sync…')} /></label>
        <div class="pcb-row">
          <label class="pcb-field" style="flex:1;"><span>{$t('Starts')}</span><input type="datetime-local" bind:value={mAt} /></label>
          <label class="pcb-field" style="flex:1;"><span>{$t('Ends')}</span><input type="datetime-local" bind:value={mEnds} /></label>
        </div>
        <div class="pcb-row">
          <label class="pcb-field" style="flex:0 0 9rem;"><span>{$t('Repeats')}</span>
            <select bind:value={mRecur}>{#each RECUR as rc}<option value={rc}>{$t(RECUR_LABEL[rc])}</option>{/each}</select>
          </label>
          <label class="pcb-field" style="flex:1;"><span>{$t('Location')}</span><input bind:value={mLoc} placeholder={$t('Zoom link or room')} /></label>
        </div>
        <label class="pcb-field"><span>{$t('Agenda')}</span><input bind:value={mAgenda} placeholder={$t('optional')} /></label>
        <button type="button" class="pcb-go" disabled={busy === 'meeting'} onclick={addMeeting}>
          {#if busy === 'meeting'}<span class="spin"></span>{/if}{$t('Schedule meeting')}
        </button>
      </div>
    {/if}

    {#if meetings.length === 0}
      <p class="pcb-muted">{$t('No meetings scheduled.')}</p>
    {:else}
      <ul class="pcb-links">
        {#each meetings as m (m.id)}
          {@const recurring = m.recurrence && m.recurrence !== 'none'}
          <li class="pcb-link-row" class:past={!recurring && isPast(m.scheduled_at)}>
            <span class="pcb-kind">{recurring ? '↻' : isPast(m.scheduled_at) ? '✓' : '📅'}</span>
            <div class="pcb-link-main">
              <span class="pcb-link-title">{m.title}{#if recurring}<span class="pcb-recur">{$t(RECUR_LABEL[m.recurrence])}</span>{/if}</span>
              <span class="pcb-link-host">{fmtWhen(m.scheduled_at, m.ends_at)}{#if m.location} · {m.location}{/if}{#if m.agenda} · {m.agenda}{/if}</span>
            </div>
            {#if canEdit}
              <button type="button" class="pcb-x" disabled={busy === m.id} title={$t('Remove')} aria-label={$t('Remove')} onclick={() => removeMeeting(m.id)}>✕</button>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </div>

  <!-- history -->
  <div class="pcb-section">
    <span class="pcb-h">{$t('History')}</span>
    {#if canEdit}
      <div class="pcb-note">
        <input bind:value={note} placeholder={$t('Add a note to the history…')} onkeydown={(e) => { if (e.key === 'Enter') postNote(); }} />
        <button type="button" class="pcb-go" disabled={busy === 'note' || !note.trim()} onclick={postNote}>{$t('Post')}</button>
      </div>
    {/if}
    {#if events.length === 0}
      <p class="pcb-muted">{$t('No activity yet.')}</p>
    {:else}
      <ul class="pcb-timeline">
        {#each events as ev (ev.id)}
          <li class="pcb-ev">
            <span class="pcb-dot"></span>
            <div class="pcb-ev-body">
              <span class="pcb-ev-text">{ev.summary}</span>
              <span class="pcb-ev-meta">{ev.member?.full_name ?? '—'} · {rel(ev.created_at)}</span>
            </div>
          </li>
        {/each}
      </ul>
    {/if}
  </div>
{/if}

<style>
  .pcb-err { font-size: .82rem; color: var(--down); margin: 0 0 .5rem; }
  .pcb-section { display: flex; flex-direction: column; gap: .5rem; padding-top: .8rem; border-top: 1px solid var(--border); }
  .pcb-h-row { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
  .pcb-h { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .pcb-ct { color: var(--text-dim); }
  .pcb-link { background: transparent; border: 0; color: var(--accent); font: inherit; font-size: .8rem; cursor: pointer; padding: 0; }
  .pcb-link:hover { text-decoration: underline; }
  .pcb-muted { font-size: .82rem; color: var(--muted); margin: 0; }

  .pcb-form { display: flex; flex-direction: column; gap: .5rem; padding: .2rem 0 .2rem; }
  .pcb-row { display: flex; gap: .5rem; flex-wrap: wrap; }
  .pcb-field { display: flex; flex-direction: column; gap: .25rem; font-size: .76rem; color: var(--muted); }
  .pcb-field input, .pcb-field select, .pcb-field textarea {
    padding: .45rem .55rem; border-radius: 8px; border: 1px solid var(--border-2);
    background: var(--card-2); color: var(--text); font-size: .88rem; font-family: inherit;
  }
  .pcb-actions { display: flex; gap: .5rem; }
  .pcb-go {
    align-self: flex-start; padding: .45rem .85rem; border-radius: 8px; border: 1px solid transparent;
    background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer;
    display: inline-flex; align-items: center; gap: .4rem;
  }
  .pcb-go:disabled { opacity: .55; cursor: not-allowed; }
  .pcb-ghost { padding: .45rem .85rem; border-radius: 8px; border: 1px solid var(--border); background: transparent; color: var(--text); font: inherit; cursor: pointer; }

  .pcb-links { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .35rem; }
  .pcb-link-row { display: flex; align-items: center; gap: .55rem; padding: .4rem .5rem; border: 1px solid var(--border); border-radius: 9px; background: var(--card); }
  .pcb-link-row.past { opacity: .6; }
  .pcb-kind { flex: none; font-size: .95rem; }
  .pcb-link-main { display: flex; flex-direction: column; gap: .05rem; text-decoration: none; color: inherit; min-width: 0; flex: 1; }
  .pcb-link-title { font-size: .86rem; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pcb-link-title:hover { color: var(--accent); }
  .pcb-recur {
    margin-left: .4rem; font-size: .64rem; font-weight: 700; text-transform: uppercase; letter-spacing: .03em;
    color: var(--accent); background: var(--accent-soft); border-radius: 999px; padding: .05rem .4rem; vertical-align: middle;
  }
  .pcb-link-host { font-size: .72rem; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pcb-x { flex: none; background: transparent; border: 0; color: var(--muted); cursor: pointer; font-size: .85rem; padding: .2rem .35rem; }
  .pcb-x:hover { color: var(--down); }

  .pcb-note { display: flex; gap: .4rem; }
  .pcb-note input { flex: 1; padding: .45rem .55rem; border-radius: 8px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .86rem; }
  .pcb-timeline { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .5rem; max-height: 240px; overflow-y: auto; }
  .pcb-ev { display: flex; gap: .55rem; }
  .pcb-dot { flex: none; width: 7px; height: 7px; border-radius: 50%; background: var(--accent); margin-top: .42rem; }
  .pcb-ev-body { display: flex; flex-direction: column; gap: .1rem; }
  .pcb-ev-text { font-size: .84rem; color: var(--text); }
  .pcb-ev-meta { font-size: .72rem; color: var(--muted); }
</style>
