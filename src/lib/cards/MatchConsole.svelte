<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import ForgeCard from './ForgeCard.svelte';
  import BadgeTree from './BadgeTree.svelte';

  // Officer console — a global matching desk. The officer's job is to pair
  // supply (people with skills, resources & monthly capacity) with demand
  // (open project slots / needs). Pick a need → qualified people surface; pick a
  // person → the needs they can fill surface; seat to commit. Scope follows the
  // unit kind: a chapter places its roster into any open need; a working group
  // fills its projects' needs with anyone in the community.
  let { unitId }: { unitId: string } = $props();

  type Person = { id: string; full_name: string; affiliation: string | null; kind: string };
  type Badge = { skill_id: string; level: string };
  type Resource = { id: string; name: string; type_id: string; monthly_quota: number | null; unit: string | null; skills?: { skill_id: string; level: string }[] };
  type Req = { skill_id: string; min_level: string };
  type Need = {
    id: string; project_id: string; project_name: string; deadline: string | null;
    slot_kind: 'leader' | 'work_labor' | 'work_resource'; req_access: string | null;
    skill_id: string | null; skill_name: string | null;
    resource_type_id: string | null; resource_type_name: string | null;
    quota: number | null; headcount: number; filled: number; requirements: Req[];
  };
  type Skill = { id: string; name: string; parent_id: string | null };
  type ResType = { id: string; name: string; unit: string | null };

  let unit = $state<{ id: string; name: string; kind: 'chapter' | 'working_group' } | null>(null);
  let people = $state<Person[]>([]);
  let badgesOf = $state<Record<string, Badge[]>>({});
  let resOf = $state<Record<string, Resource[]>>({});
  let usedOf = $state<Record<string, number>>({});       // labor used this month, per member (display)
  let usedByRes = $state<Record<string, number>>({});    // committed this month, per resource_id (capacity)
  let needs = $state<Need[]>([]);
  let unclaimed = $state<{ id: string; name: string; status: string }[]>([]);
  let ownedProjects = $state<{ id: string; name: string }[]>([]);
  let skills = $state<Skill[]>([]);
  let resTypes = $state<ResType[]>([]);
  let loading = $state(true);
  let msg = $state(''); let err = $state(''); let busy = $state('');

  const ym = new Date().toISOString().slice(0, 7);
  const isOfficer = $derived(
    !!unit && (get(capabilities).has('manage_members') || get(capabilities).has('edit_any_project')
      || get(officerUnits).some((u) => u.unit_id === unit!.id))
  );
  const isChapter = $derived(unit?.kind === 'chapter');

  const RANK: Record<string, number> = { apprentice: 1, journeyman: 2, craftsman: 3, master: 4 };
  const rank = (l: string | null | undefined) => (l ? RANK[l] ?? 0 : 0);

  // ---- selection drives the match ----
  let selNeed = $state<Need | null>(null);
  let selPerson = $state<Person | null>(null);
  let q = $state('');
  // seat form
  let amount = $state<number>(0);
  let resId = $state<string>('');

  const skillName = (id: string) => skills.find((s) => s.id === id)?.name ?? '';

  // Every need is "skill(s) + a resource". The resource is mandatory — hold a
  // resource of the slot's type WITH monthly capacity left (a labor need's type
  // is 'Labor', i.e. working hours). Skills are optional: satisfy each
  // requirement in the requirements jsonb if any are declared.
  function qualify(s: Need, badges: Badge[], resources: Resource[]): { ok: boolean; reason: string } {
    if (s.filled >= s.headcount) return { ok: false, reason: get(t)('Filled') };
    for (const req of s.requirements) {
      const have = badges.find((b) => b.skill_id === req.skill_id);
      const byBadge = !!have && rank(have.level) >= rank(req.min_level);
      // custody channel: a stewarded resource that declares the skill at level also qualifies
      const byResource = resources.some((r) => Array.isArray(r.skills) && r.skills.some((rs) => rs.skill_id === req.skill_id && rank(rs.level) >= rank(req.min_level)));
      if (!byBadge && !byResource) {
        const nm = skillName(req.skill_id);
        return { ok: false, reason: get(t)('Needs {lvl} {skill}', { lvl: get(t)(req.min_level), skill: nm }) };
      }
    }
    if (s.resource_type_id) {
      const res = resources.find((r) => r.type_id === s.resource_type_id);
      if (!res) return { ok: false, reason: get(t)('No matching resource held') };
      const remaining = res.monthly_quota == null ? Infinity : res.monthly_quota - (usedByRes[res.id] ?? 0);
      if (remaining <= 0) return { ok: false, reason: get(t)('No capacity left this month') };
    }
    return { ok: true, reason: '' };
  }

  async function load(uid: string) {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; err = ''; selNeed = null; selPerson = null;
    const { data: u } = await supabase.from('org_unit').select('id, name, kind').eq('id', uid).maybeSingle();
    if (!u) { unit = null; loading = false; return; }
    unit = u as any;

    const [{ data: sl }, { data: sk }, { data: rt }] = await Promise.all([
      // a leader is just another need (skill(s) + the Labor resource), seated
      // like any other — load all open work + leader slots.
      supabase.from('project_slot')
        .select('id, project_id, slot_kind, req_access, skill_id, resource_type_id, quota, headcount, status, requirements, project:project_id(name, deadline, org_unit_id), skill:skill_id(name), resource_type:resource_type_id(name)')
        .eq('status', 'open').in('slot_kind', ['leader', 'work_labor', 'work_resource']),
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('resource_type').select('id, name, unit').order('rank')
    ]);
    skills = (sk as Skill[]) ?? [];
    resTypes = (rt as ResType[]) ?? [];

    // demand scope: a WG fills only its own projects' needs; a chapter sees all
    let rawNeeds = ((sl as any[]) ?? []);
    if (unit!.kind === 'working_group') rawNeeds = rawNeeds.filter((s) => s.project?.org_unit_id === uid);
    const needIds = rawNeeds.map((s) => s.id);
    const fill: Record<string, Set<string>> = {};
    if (needIds.length) {
      const { data: wc } = await supabase.from('work_commitment').select('slot_id, member_id').in('slot_id', needIds);
      for (const w of (wc as any[]) ?? []) (fill[w.slot_id] ??= new Set()).add(w.member_id);
    }
    needs = rawNeeds.map((s) => ({
      id: s.id, project_id: s.project_id, project_name: s.project?.name ?? '—',
      deadline: s.project?.deadline ?? null, slot_kind: s.slot_kind, req_access: s.req_access,
      skill_id: s.skill_id, skill_name: s.skill?.name ?? null,
      resource_type_id: s.resource_type_id, resource_type_name: s.resource_type?.name ?? null,
      quota: s.quota, headcount: s.headcount ?? 1, filled: fill[s.id]?.size ?? 0,
      requirements: (Array.isArray(s.requirements) ? s.requirements : []) as Req[]
    })).filter((n) => n.filled < n.headcount);

    // supply side is the chapter's roster — a chapter places its people into
    // open needs. A working group doesn't actively push candidates; its console
    // is just its open needs + claim / post-need, so skip the supply load.
    if (unit!.kind === 'chapter') {
      const { data: pl } = await supabase.from('member')
        .select('id, full_name, affiliation, kind, status').eq('home_unit_id', uid).order('full_name');
      people = (pl as Person[]) ?? [];
    } else people = [];
    const pids = people.map((p) => p.id);

    if (pids.length) {
      const laborType = resTypes.find((r) => r.name === 'Labor')?.id ?? null;
      const [{ data: bg }, { data: rs }, { data: wc }] = await Promise.all([
        supabase.from('badge').select('member_id, skill_id, level').in('member_id', pids),
        supabase.from('resource').select('id, name, type_id, monthly_quota, unit, holder_member_id, skills').in('holder_member_id', pids),
        supabase.from('work_commitment').select('member_id, monthly_amount, resource_id').in('member_id', pids).eq('year_month', ym)
      ]);
      const bmap: Record<string, Badge[]> = {};
      for (const b of (bg as any[]) ?? []) (bmap[b.member_id] ??= []).push({ skill_id: b.skill_id, level: b.level });
      badgesOf = bmap;
      const rmap: Record<string, Resource[]> = {};
      for (const r of (rs as Resource[] & { holder_member_id: string }[]) ?? [])
        (rmap[(r as any).holder_member_id] ??= []).push(r);
      resOf = rmap;
      // committed this month — per member (display) and per resource (capacity)
      const used: Record<string, number> = {};
      const usedRes: Record<string, number> = {};
      for (const w of (wc as any[]) ?? []) {
        used[w.member_id] = (used[w.member_id] ?? 0) + (Number(w.monthly_amount) || 0);
        if (w.resource_id) usedRes[w.resource_id] = (usedRes[w.resource_id] ?? 0) + (Number(w.monthly_amount) || 0);
      }
      usedOf = used;
      usedByRes = usedRes;
      void laborType;
    } else { badgesOf = {}; resOf = {}; usedOf = {}; usedByRes = {}; }

    // WG: unclaimed projects to take on + this group's projects (to post needs)
    if (unit!.kind === 'working_group' && isOfficer) {
      const [{ data: free }, { data: owned }] = await Promise.all([
        supabase.from('project').select('id, name, project_status!project_status_id_fkey(name)').is('org_unit_id', null).order('name').limit(50),
        supabase.from('project').select('id, name, project_status!project_status_id_fkey(is_active)').eq('org_unit_id', uid).order('name')
      ]);
      unclaimed = ((free as any[]) ?? []).map((p) => ({ id: p.id, name: p.name, status: p.project_status?.name ?? '—' }));
      ownedProjects = ((owned as any[]) ?? []).filter((p) => p.project_status?.is_active !== false).map((p) => ({ id: p.id, name: p.name }));
    } else { unclaimed = []; ownedProjects = []; }

    loading = false;
  }

  // capacity headline per person (labor): quota − used
  function capOf(p: Person): { quota: number | null; used: number; unit: string } {
    const res = (resOf[p.id] ?? []).find((r) => resTypes.find((t) => t.id === r.type_id)?.name === 'Labor')
      ?? (resOf[p.id] ?? [])[0];
    const used = usedOf[p.id] ?? 0;
    return { quota: res?.monthly_quota ?? null, used, unit: res?.unit ?? 'h' };
  }

  // ---- ranked lists, biased by the current selection ----
  const peopleView = $derived.by(() => {
    const needle = q.trim().toLowerCase();
    let list = people.filter((p) => !needle || p.full_name.toLowerCase().includes(needle)
      || (p.affiliation ?? '').toLowerCase().includes(needle));
    if (selNeed) {
      const s = selNeed;
      list = [...list].sort((a, b) => {
        const qa = qualify(s, badgesOf[a.id] ?? [], resOf[a.id] ?? []).ok;
        const qb = qualify(s, badgesOf[b.id] ?? [], resOf[b.id] ?? []).ok;
        return qa === qb ? a.full_name.localeCompare(b.full_name) : qa ? -1 : 1;
      });
    }
    return list;
  });
  // leader is just another need now (skill(s) + Labor), seated like the rest —
  // no special handling, so the board shows every open need.
  const boardNeeds = $derived(needs);
  const needsView = $derived.by(() => {
    let list = boardNeeds;
    if (selPerson) {
      const bd = badgesOf[selPerson.id] ?? [], rs = resOf[selPerson.id] ?? [];
      list = [...list].sort((a, b) => {
        const qa = qualify(a, bd, rs).ok, qb = qualify(b, bd, rs).ok;
        if (qa !== qb) return qa ? -1 : 1;
        return (b.headcount - b.filled) - (a.headcount - a.filled);
      });
    }
    return list;
  });

  const seatFit = $derived.by(() => {
    if (!selNeed || !selPerson) return null;
    return qualify(selNeed, badgesOf[selPerson.id] ?? [], resOf[selPerson.id] ?? []);
  });

  function pickNeed(n: Need) {
    selNeed = selNeed?.id === n.id ? null : n;
    if (selNeed) { amount = selNeed.quota ?? 0; resId = ''; resetResDefault(); }
  }
  function pickPerson(p: Person) {
    selPerson = selPerson?.id === p.id ? null : p;
    resetResDefault();
  }
  function resetResDefault() {
    if (selNeed && selPerson && selNeed.resource_type_id) {
      const m = (resOf[selPerson.id] ?? []).find((r) => r.type_id === selNeed!.resource_type_id);
      resId = m?.id ?? '';
    } else resId = '';
  }

  async function seat() {
    if (!selNeed || !selPerson) return;
    busy = 'seat'; err = ''; msg = '';
    const { error: e } = await supabase.rpc('work_seat', {
      p_slot: selNeed.id, p_member: selPerson.id, p_resource: resId || null,
      p_year_month: ym, p_monthly_amount: Number(amount) || 0, p_as: selPerson.id
    });
    busy = '';
    if (e) { err = e.message; return; }
    msg = get(t)('Seated into slot.'); await load(unitId);
  }

  // ---- secondary forge actions ----
  let showForgeMember = $state(false);
  let forgeBadgeFor = $state<Person | null>(null);
  let postNeedFor = $state<{ id: string; name: string } | null>(null);

  async function forgeMember(p: Record<string, any>) {
    busy = 'member'; err = ''; msg = '';
    const { error: e } = await supabase.rpc('forge_member_card', {
      p_full_name: p.full_name, p_email: p.email, p_unit: unitId,
      p_affiliation: p.affiliation || null, p_badges: []
    });
    busy = '';
    if (e) { err = e.message; return; }
    msg = get(t)('Card forged.'); showForgeMember = false; await load(unitId);
  }
  async function claim(p: { id: string }) {
    busy = p.id; err = ''; msg = '';
    const { error: e } = await supabase.rpc('forge_claim', { p_project: p.id, p_wg_unit: unitId });
    busy = '';
    if (e) { err = e.message; return; }
    msg = get(t)('Project claimed.'); await load(unitId);
  }
  async function postNeed(payload: Record<string, any>) {
    if (!postNeedFor) return;
    busy = 'need'; err = ''; msg = '';
    const { error: e } = await supabase.rpc('forge_need', {
      p_project: postNeedFor.id, p_slot_kind: payload.slot_kind, p_req_access: payload.req_access,
      p_skill: payload.skill, p_resource_type: payload.resource_type, p_quota: payload.quota,
      p_headcount: payload.headcount, p_requirements: payload.requirements ?? []
    });
    busy = '';
    if (e) { err = e.message; return; }
    msg = get(t)('Need submitted for review.'); postNeedFor = null; await load(unitId);
  }
  // projects this WG owns (to post needs against)
  const myProjects = $derived(ownedProjects);

  function fmtDeadline(d: string | null) {
    if (!d) return '';
    return new Date(d + 'T00:00:00').toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  }
  function kindLabel(k: string) {
    return k === 'work_resource' ? $t('Resource need') : k === 'leader' ? $t('Lead open') : $t('Labor need');
  }

  let lastId = '';
  $effect(() => { if (unitId && unitId !== lastId) { lastId = unitId; load(unitId); } });
</script>

{#if loading}
  <div class="sk sk-row"></div><div class="sk sk-row"></div>
{:else if !unit}
  <p class="muted">{$t('No such unit.')}</p>
{:else}
  <div class="mc">
    <header class="mc-head">
      <div>
        <h2 class="mc-title">{unit.name}</h2>
        <p class="mc-sub">
          {isChapter ? $t('Chapter') : $t('Working group')} · {$t('Month {ym}', { ym })}
          · {$t('{n} open needs', { n: boardNeeds.length })}
        </p>
      </div>
      {#if isOfficer && isChapter}
        <button type="button" class="stake" onclick={() => (showForgeMember = !showForgeMember)}>+ {$t('Forge member card')}</button>
      {/if}
    </header>

    {#if err}<p class="mc-err">{err}</p>{/if}
    {#if msg}<p class="mc-msg">{msg}</p>{/if}

    {#if showForgeMember}
      <div class="tile" style="padding:1rem;">
        <ForgeCard mode="member" busy={busy === 'member'} title={$t('Forge member card')}
          onSubmit={forgeMember} onCancel={() => (showForgeMember = false)} />
      </div>
    {/if}

    <!-- WG: take on unclaimed projects -->
    {#if isOfficer && !isChapter && unclaimed.length}
      <section class="mc-claims">
        <span class="mc-h">{$t('Unclaimed projects')}</span>
        <div class="claim-rows">
          {#each unclaimed as p (p.id)}
            <div class="claim-row">
              <span class="claim-name">{p.name}</span>
              <span class="badge dim">{$t(p.status)}</span>
              <button type="button" class="chip toggle" disabled={busy === p.id} onclick={() => claim(p)}>{$t('Claim')}</button>
            </div>
          {/each}
        </div>
      </section>
    {/if}

    <!-- seat bar: appears when a need + a person are both picked (chapter) -->
    {#if isChapter && selNeed && selPerson}
      <div class="seatbar" class:bad={seatFit && !seatFit.ok}>
        <div class="sb-text">
          <strong>{selPerson.full_name}</strong> → <strong>{selNeed.project_name}</strong>
          <span class="sb-kind">{kindLabel(selNeed.slot_kind)}{#if selNeed.skill_name} · {selNeed.skill_name}{/if}</span>
          {#if seatFit && !seatFit.ok}<span class="sb-reason">· {seatFit.reason}</span>{/if}
        </div>
        {#if seatFit?.ok}
          <div class="sb-form">
            <label>{$t('Monthly amount')}<input type="number" min="0" step="any" bind:value={amount} /></label>
            {#if selNeed.resource_type_id}
              <label>{$t('Resource')}
                <select bind:value={resId}>
                  <option value="">{$t('Select resource')}</option>
                  {#each (resOf[selPerson.id] ?? []).filter((r) => r.type_id === selNeed.resource_type_id) as r (r.id)}
                    <option value={r.id}>{r.name}</option>
                  {/each}
                </select>
              </label>
            {/if}
            <button type="button" class="stake" disabled={busy === 'seat' || (!!selNeed.resource_type_id && !resId)} onclick={seat}>
              {#if busy === 'seat'}<span class="spin"></span>{/if}{$t('Seat into slot')}
            </button>
          </div>
        {/if}
      </div>
    {/if}

    <!-- the matching board: chapter = needs (demand) ⟷ roster (supply);
         a working group only sees its open needs (no active candidate push) -->
    <div class="board" class:single={!isChapter}>
      <!-- demand -->
      <section class="col">
        <span class="mc-h">{$t('Open needs')}{#if boardNeeds.length}<span class="mc-ct"> · {boardNeeds.length}</span>{/if}</span>
        {#if !boardNeeds.length}
          <p class="muted">{isChapter ? $t('No open needs in the community right now.') : $t('No open needs — take on a project or post one.')}</p>
        {:else}
          <div class="rows">
            {#each needsView as n (n.id)}
              {#if isChapter}
                {@const fit = selPerson ? qualify(n, badgesOf[selPerson.id] ?? [], resOf[selPerson.id] ?? []) : null}
                <button type="button" class="row need" class:on={selNeed?.id === n.id}
                  class:fit={fit?.ok} class:dim={fit && !fit.ok} onclick={() => pickNeed(n)}>
                  <span class="r-main">
                    <span class="r-title">{n.project_name}</span>
                    <span class="r-sub">{kindLabel(n.slot_kind)}{#if n.skill_name} · {n.skill_name}{/if}{#if n.resource_type_name} · {n.resource_type_name}{/if}{#if n.req_access} · {$t('needs {lvl}', { lvl: $t(n.req_access) })}{/if}</span>
                  </span>
                  <span class="r-meta">
                    <span class="r-gap">{n.headcount - n.filled}/{n.headcount}</span>
                    {#if n.deadline}<span class="r-ddl">{fmtDeadline(n.deadline)}</span>{/if}
                  </span>
                </button>
              {:else}
                <a class="row need" href={`/projects/${n.project_id}`}>
                  <span class="r-main">
                    <span class="r-title">{n.project_name}</span>
                    <span class="r-sub">{kindLabel(n.slot_kind)}{#if n.skill_name} · {n.skill_name}{/if}{#if n.resource_type_name} · {n.resource_type_name}{/if}{#if n.req_access} · {$t('needs {lvl}', { lvl: $t(n.req_access) })}{/if}</span>
                  </span>
                  <span class="r-meta">
                    <span class="r-gap">{n.headcount - n.filled}/{n.headcount}</span>
                    {#if n.deadline}<span class="r-ddl">{fmtDeadline(n.deadline)}</span>{/if}
                  </span>
                </a>
              {/if}
            {/each}
          </div>
        {/if}
      </section>

      <!-- supply (chapter only) -->
      {#if isChapter}
        <section class="col">
          <div class="col-head">
            <span class="mc-h">{$t('Roster')}{#if people.length}<span class="mc-ct"> · {people.length}</span>{/if}</span>
            <div class="search"><input placeholder={$t('Search by name…')} bind:value={q} /></div>
          </div>
          {#if !peopleView.length}
            <p class="muted">{$t('No members yet.')}</p>
          {:else}
            <div class="rows">
              {#each peopleView.slice(0, 120) as p (p.id)}
                {@const fit = selNeed ? qualify(selNeed, badgesOf[p.id] ?? [], resOf[p.id] ?? []) : null}
                {@const cap = capOf(p)}
                <div class="prow" class:on={selPerson?.id === p.id} class:fit={fit?.ok} class:dim={fit && !fit.ok}>
                  <button type="button" class="row person" onclick={() => pickPerson(p)}>
                    <span class="r-main">
                      <span class="r-title">{p.full_name}{#if p.kind === 'card'}<span class="badge dim card-b">{$t('card')}</span>{/if}</span>
                      <span class="r-sub">
                        {#if cap.quota != null}{$t('{used}/{quota} {unit} used', { used: cap.used, quota: cap.quota, unit: cap.unit })}{:else}{p.affiliation ?? '—'}{/if}
                        {#if (badgesOf[p.id] ?? []).length} · {$t('{n} badges', { n: (badgesOf[p.id] ?? []).length })}{/if}
                        {#if fit && !fit.ok} · <span class="r-reason">{fit.reason}</span>{/if}
                      </span>
                    </span>
                  </button>
                  {#if isOfficer}
                    <button type="button" class="r-badge" title={$t('Badges')} onclick={() => (forgeBadgeFor = p)}>✦</button>
                  {/if}
                </div>
              {/each}
              {#if peopleView.length > 120}<p class="muted" style="text-align:center;">{$t('Showing first {n} — refine your search.', { n: 120 })}</p>{/if}
            </div>
          {/if}
        </section>
      {/if}
    </div>

    <!-- WG: post a need against an owned project -->
    {#if isOfficer && !isChapter && myProjects.length}
      <section class="mc-claims">
        <span class="mc-h">{$t('Post a need')}</span>
        <div class="claim-rows">
          {#each myProjects as p (p.id)}
            <div class="claim-row">
              <span class="claim-name">{p.name}</span>
              <button type="button" class="chip toggle" onclick={() => (postNeedFor = p)}>+ {$t('Post need')}</button>
            </div>
          {/each}
        </div>
      </section>
    {/if}
  </div>

  {#if forgeBadgeFor}
    <div class="mc-backdrop" onclick={() => (forgeBadgeFor = null)} role="presentation"></div>
    <aside class="mc-drawer" role="dialog">
      <header class="d-head"><span>{$t('Badges')} · {forgeBadgeFor.full_name}</span>
        <button type="button" class="x" onclick={() => (forgeBadgeFor = null)}>✕</button></header>
      <div class="d-body">
        <BadgeTree memberId={forgeBadgeFor.id} canEdit={true}
          onSubmitted={() => { msg = get(t)('Badges submitted for review.'); load(unitId); }} />
      </div>
    </aside>
  {/if}

  {#if postNeedFor}
    <div class="mc-backdrop" onclick={() => (postNeedFor = null)} role="presentation"></div>
    <aside class="mc-drawer" role="dialog">
      <header class="d-head"><span>{$t('Post need')} · {postNeedFor.name}</span>
        <button type="button" class="x" onclick={() => (postNeedFor = null)}>✕</button></header>
      <div class="d-body">
        <ForgeCard mode="need" {skills} resourceTypes={resTypes} busy={busy === 'need'}
          onSubmit={postNeed} onCancel={() => (postNeedFor = null)} />
      </div>
    </aside>
  {/if}
{/if}

<style>
  .mc { display: flex; flex-direction: column; gap: 1rem; }
  .mc-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; }
  .mc-title { font-size: 1.25rem; font-weight: 600; color: var(--text); margin: 0; }
  .mc-sub { font-size: .82rem; color: var(--muted); margin: .2rem 0 0; }
  .mc-err { font-size: .85rem; color: var(--down); margin: 0; }
  .mc-msg { font-size: .85rem; color: var(--accent); margin: 0; }
  .mc-h { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .mc-ct { color: var(--text-dim); }
  .muted { color: var(--muted); font-size: .88rem; }

  .mc-claims { display: flex; flex-direction: column; gap: .5rem; }
  .claim-rows { display: flex; flex-direction: column; gap: .4rem; }
  .claim-row { display: flex; align-items: center; gap: .6rem; padding: .5rem .7rem; border: 1px solid var(--border); border-radius: 9px; background: var(--card); }
  .claim-name { font-weight: 500; color: var(--text); flex: 1; min-width: 0; }

  /* seat bar */
  .seatbar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: .6rem 1rem;
    padding: .7rem .9rem; border: 1px solid var(--accent); border-radius: 12px; background: var(--accent-soft); }
  .seatbar.bad { border-color: var(--border); background: var(--card-2); }
  .sb-text { font-size: .9rem; color: var(--text); }
  .sb-kind { color: var(--muted); font-size: .8rem; margin-left: .3rem; }
  .sb-reason { color: var(--down); font-size: .8rem; }
  .sb-form { display: flex; flex-wrap: wrap; gap: .5rem; align-items: flex-end; }
  .sb-form label { display: flex; flex-direction: column; gap: .2rem; font-size: .72rem; color: var(--muted); }
  .sb-form input, .sb-form select { padding: .4rem .5rem; border-radius: 8px; border: 1px solid var(--border-2); background: var(--card); color: var(--text); font-size: .85rem; max-width: 9rem; }

  /* board */
  .board { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; align-items: start; }
  .board.single { grid-template-columns: 1fr; }
  @media (max-width: 720px) { .board { grid-template-columns: 1fr; } }
  .row { text-decoration: none; }
  .col { display: flex; flex-direction: column; gap: .5rem; min-width: 0; }
  .col-head { display: flex; align-items: center; justify-content: space-between; gap: .6rem; }
  .col-head .search { max-width: 11rem; }
  .search input { width: 100%; }
  .rows { display: flex; flex-direction: column; gap: .4rem; }

  .row { display: flex; align-items: center; justify-content: space-between; gap: .6rem; width: 100%;
    text-align: left; padding: .55rem .7rem; border: 1px solid var(--border); border-radius: 9px;
    background: var(--card); color: var(--text); font: inherit; cursor: pointer; transition: border-color .12s ease, background .12s ease; }
  .row:hover { border-color: var(--accent); }
  .row.on { border-color: var(--accent); background: var(--accent-soft); }
  .row.fit { border-color: color-mix(in srgb, var(--up, var(--accent)) 45%, transparent); }
  .row.dim { opacity: .5; }
  .r-main { display: flex; flex-direction: column; gap: .15rem; min-width: 0; }
  .r-title { font-weight: 500; font-size: .9rem; display: flex; align-items: center; gap: .35rem; }
  .r-sub { font-size: .76rem; color: var(--muted); }
  .r-reason { color: var(--down); }
  .r-meta { display: flex; flex-direction: column; align-items: flex-end; gap: .1rem; flex: none; }
  .r-gap { font-variant-numeric: tabular-nums; font-size: .82rem; color: var(--text-dim); }
  .r-ddl { font-size: .7rem; color: var(--muted); }
  .card-b { font-size: .64rem; }

  .prow { display: flex; align-items: stretch; gap: .35rem; }
  .prow.on > .person { border-color: var(--accent); background: var(--accent-soft); }
  .prow.fit > .person { border-color: color-mix(in srgb, var(--up, var(--accent)) 45%, transparent); }
  .prow.dim { opacity: .5; }
  .prow > .person { flex: 1; min-width: 0; }
  .r-badge { flex: none; width: 2rem; border: 1px solid var(--border); border-radius: 9px; background: var(--card);
    color: var(--accent); font-size: .9rem; cursor: pointer; }
  .r-badge:hover { border-color: var(--accent); }

  .mc-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 80; }
  .mc-drawer { position: fixed; top: 0; right: 0; bottom: 0; width: min(400px, 100vw); z-index: 90;
    background: var(--card); border-left: 1px solid var(--border-2); box-shadow: var(--shadow); display: flex; flex-direction: column; }
  .d-head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.1rem; border-bottom: 1px solid var(--border); font-weight: 600; color: var(--text); }
  .d-body { padding: 1rem 1.1rem; overflow-y: auto; }
  .x { background: transparent; border: 0; color: var(--muted); font-size: 1rem; cursor: pointer; }
  .x:hover { color: var(--text); filter: none; }
</style>
