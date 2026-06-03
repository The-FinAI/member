<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import MemberCard, { type CardBadge, type CardCommit, type Person } from './MemberCard.svelte';
  import Matcher, { type MatchSlot, type HeldResource } from './Matcher.svelte';
  import ForgeCard from './ForgeCard.svelte';
  import BadgeTree from './BadgeTree.svelte';

  // Chapter officer console — the binder of member cards. Forge cards/badges/
  // resources, see each card's monthly capacity + commitments, and invest a
  // card into an open project slot via the Matcher.
  let { unitId }: { unitId: string } = $props();

  type Skill = { id: string; name: string; parent_id: string | null };
  type ResType = { id: string; name: string; unit: string | null };
  type Resource = { id: string; name: string; type_id: string; monthly_quota: number | null; unit: string | null; holder_member_id: string };

  let unit = $state<{ id: string; name: string; kind: string } | null>(null);
  let cards = $state<Person[]>([]);
  let badgesByCard = $state<Record<string, CardBadge[]>>({});
  let resByCard = $state<Record<string, Resource[]>>({});
  let commitsByCard = $state<Record<string, CardCommit[]>>({});
  let skills = $state<Skill[]>([]);
  let resTypes = $state<ResType[]>([]);
  let openSlots = $state<MatchSlot[]>([]);
  let loading = $state(true);
  let msg = $state(''); let error = '';
  let busy = $state('');

  const ym = new Date().toISOString().slice(0, 7);
  const laborTypeId = $derived(resTypes.find((r) => r.name === 'Labor')?.id ?? null);

  const isOfficer = $derived(
    !!unit && (get(capabilities).has('manage_members') || get(officerUnits).some((u) => u.unit_id === unit!.id))
  );

  // forge / matcher UI state
  let showForgeMember = $state(false);
  let forgeBadgeFor = $state<Person | null>(null);
  let matchFor = $state<Person | null>(null);
  let expandedId = $state<string | null>(null);

  async function load(uid: string) {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; error = '';
    const { data: u } = await supabase.from('org_unit').select('id, name, kind').eq('id', uid).maybeSingle();
    if (!u) { unit = null; loading = false; return; }
    unit = u as any;

    const [{ data: c }, { data: sk }, { data: rt }] = await Promise.all([
      // everyone homed in this chapter — unclaimed cards AND claimed members;
      // officers manage badges / seating for the whole roster, not just cards.
      supabase.from('member').select('id, full_name, affiliation, email, status, kind')
        .eq('home_unit_id', uid).order('full_name'),
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('resource_type').select('id, name, unit').order('rank')
    ]);
    cards = (c as Person[]) ?? [];
    skills = (sk as Skill[]) ?? [];
    resTypes = (rt as ResType[]) ?? [];
    const ids = cards.map((m) => m.id);

    if (ids.length) {
      const [{ data: bg }, { data: rs }, { data: wc }] = await Promise.all([
        supabase.from('badge').select('member_id, skill_id, level, skill:skill_id(name)').in('member_id', ids),
        supabase.from('resource').select('id, name, type_id, monthly_quota, unit, holder_member_id').in('holder_member_id', ids),
        supabase.from('work_commitment')
          .select('id, slot_id, project_id, member_id, resource_id, monthly_amount, approval, project:project_id(name)')
          .in('member_id', ids).eq('year_month', ym)
      ]);
      const bmap: Record<string, CardBadge[]> = {};
      for (const b of (bg as any[]) ?? []) {
        (bmap[b.member_id] ??= []).push({ skill_id: b.skill_id, skill_name: b.skill?.name ?? '—', level: b.level });
      }
      badgesByCard = bmap;

      const rmap: Record<string, Resource[]> = {};
      for (const r of (rs as Resource[]) ?? []) (rmap[r.holder_member_id] ??= []).push(r);
      resByCard = rmap;

      const cmap: Record<string, CardCommit[]> = {};
      for (const w of (wc as any[]) ?? []) {
        const res = ((rs as Resource[]) ?? []).find((r) => r.id === w.resource_id);
        const quota = res?.monthly_quota ?? 0;
        (cmap[w.member_id] ??= []).push({
          id: w.id, slot_id: w.slot_id, project_id: w.project_id,
          project_name: w.project?.name ?? '—', monthly_amount: Number(w.monthly_amount) || 0,
          unit: res?.unit ?? 'h', share: quota > 0 ? (Number(w.monthly_amount) || 0) / quota : 0,
          approval: w.approval
        });
      }
      commitsByCard = cmap;
    } else {
      badgesByCard = {}; resByCard = {}; commitsByCard = {};
    }

    await loadOpenSlots();
    loading = false;
  }

  async function loadOpenSlots() {
    const { data: sl } = await supabase.from('project_slot')
      .select('id, project_id, slot_kind, req_access, skill_id, resource_type_id, quota, headcount, status, project:project_id(name, deadline), skill:skill_id(name), resource_type:resource_type_id(name)')
      .eq('status', 'open').in('slot_kind', ['work_labor', 'work_resource']);
    const slots = (sl as any[]) ?? [];
    // filled = distinct members committed to each slot
    const ids = slots.map((s) => s.id);
    const fillMap: Record<string, Set<string>> = {};
    if (ids.length) {
      const { data: wc } = await supabase.from('work_commitment').select('slot_id, member_id').in('slot_id', ids);
      for (const w of (wc as any[]) ?? []) (fillMap[w.slot_id] ??= new Set()).add(w.member_id);
    }
    openSlots = slots.map((s) => ({
      id: s.id, project_id: s.project_id, project_name: s.project?.name ?? '—',
      slot_kind: s.slot_kind, req_access: s.req_access, skill_id: s.skill_id,
      skill_name: s.skill?.name ?? null, resource_type_id: s.resource_type_id,
      resource_type_name: s.resource_type?.name ?? null, quota: s.quota,
      headcount: s.headcount ?? 1, filled: fillMap[s.id]?.size ?? 0,
      deadline: s.project?.deadline ?? null
    }));
  }

  function capacityOf(card: Person): { quota: number | null; used: number; unit: string } {
    const res = (resByCard[card.id] ?? []).find((r) => r.type_id === laborTypeId)
      ?? (resByCard[card.id] ?? [])[0];
    if (!res) return { quota: null, used: 0, unit: 'h' };
    const used = (commitsByCard[card.id] ?? [])
      .filter((c) => true) // headline: sum all labor commitments
      .reduce((sum, c) => sum + (c.unit === (res.unit ?? 'h') ? c.monthly_amount : 0), 0);
    return { quota: res.monthly_quota ?? null, used, unit: res.unit ?? 'h' };
  }

  // ---- actions ----
  async function doForgeMember(p: Record<string, any>) {
    busy = 'member';
    const { error: e } = await supabase.rpc('forge_member_card', {
      p_full_name: p.full_name, p_email: p.email, p_unit: unitId,
      p_affiliation: p.affiliation || null, p_badges: []
    });
    busy = '';
    if (e) { msg = e.message; return; }
    msg = get(t)('Card forged.'); showForgeMember = false; await load(unitId);
  }

  async function doForgeBadge(p: Record<string, any>) {
    if (!forgeBadgeFor) return;
    busy = 'badge';
    const { error: e } = await supabase.rpc('forge_badge', {
      p_member: forgeBadgeFor.id, p_skill: p.skill, p_level: p.level, p_as: forgeBadgeFor.id
    });
    busy = '';
    if (e) { msg = e.message; return; }
    msg = get(t)('Badge submitted for review.'); forgeBadgeFor = null;
  }

  async function doSeat(slot: MatchSlot, resourceId: string | null, amount: number) {
    if (!matchFor) return;
    busy = slot.id;
    const { error: e } = await supabase.rpc('work_seat', {
      p_slot: slot.id, p_member: matchFor.id, p_resource: resourceId,
      p_year_month: ym, p_monthly_amount: amount, p_as: matchFor.id
    });
    busy = '';
    if (e) { msg = e.message; return; }
    msg = get(t)('Seated into slot.'); matchFor = null; await load(unitId);
  }

  function heldResources(card: Person): HeldResource[] {
    return (resByCard[card.id] ?? []).map((r) => ({ id: r.id, name: r.name, type_id: r.type_id, unit: r.unit }));
  }

  let lastId = '';
  $effect(() => {
    if (unitId && unitId !== lastId) { lastId = unitId; load(unitId); }
  });
</script>

{#if loading}
  <div class="sk sk-row"></div><div class="sk sk-row"></div>
{:else if !unit}
  <p class="muted">{$t('Chapter not found.')}</p>
{:else}
  <div class="binder">
    <header class="b-head">
      <div>
        <h2 class="b-title">{unit.name}</h2>
        <p class="b-sub">{$t('{n} members', { n: cards.length })} · {$t('Month {ym}', { ym })}</p>
      </div>
      {#if isOfficer}
        <button type="button" class="stake" onclick={() => (showForgeMember = !showForgeMember)}>
          + {$t('Forge member card')}
        </button>
      {/if}
    </header>

    {#if msg}<p class="b-msg">{msg}</p>{/if}

    {#if showForgeMember}
      <div class="tile b-forge">
        <ForgeCard mode="member" busy={busy === 'member'} title={$t('Forge member card')}
          onSubmit={doForgeMember} onCancel={() => (showForgeMember = false)} />
      </div>
    {/if}

    <div class="b-list rise-stagger">
      {#each cards as card (card.id)}
        <MemberCard
          {card}
          badges={badgesByCard[card.id] ?? []}
          commitments={commitsByCard[card.id] ?? []}
          capacity={capacityOf(card)}
          seatCount={(commitsByCard[card.id] ?? []).length}
          expanded={expandedId === card.id}
          onToggle={() => (expandedId = expandedId === card.id ? null : card.id)}
          onMatch={() => (matchFor = card)}
          onForgeBadge={isOfficer ? () => (forgeBadgeFor = card) : undefined}
        />
      {/each}
      {#if !cards.length}
        <p class="muted">{$t('No members yet — forge the first card.')}</p>
      {/if}
    </div>
  </div>

  {#if matchFor}
    <Matcher
      cardName={matchFor.full_name}
      slots={openSlots}
      badges={(badgesByCard[matchFor.id] ?? []).map((b) => ({ skill_id: b.skill_id, level: b.level }))}
      resources={heldResources(matchFor)}
      {busy}
      onSeat={doSeat}
      onClose={() => (matchFor = null)}
    />
  {/if}

  {#if forgeBadgeFor}
    <div class="matcher-backdrop" onclick={() => (forgeBadgeFor = null)} role="presentation"></div>
    <aside class="forge-drawer" role="dialog">
      <header class="fd-head">
        <span>{$t('Badges')} · {forgeBadgeFor.full_name}</span>
        <button type="button" class="x" onclick={() => (forgeBadgeFor = null)}>✕</button>
      </header>
      <div class="fd-body">
        <BadgeTree memberId={forgeBadgeFor.id} canEdit={true}
          onSubmitted={() => { msg = get(t)('Badges submitted for review.'); load(unitId); }} />
      </div>
    </aside>
  {/if}
{/if}

<style>
  .binder { display: flex; flex-direction: column; gap: 1rem; }
  .b-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; }
  .b-title { font-size: 1.25rem; font-weight: 600; color: var(--text); margin: 0; }
  .b-sub { font-size: .82rem; color: var(--muted); margin: .2rem 0 0; }
  .b-msg { font-size: .85rem; color: var(--accent); }
  .b-forge { padding: 1rem; }
  .b-list { display: flex; flex-direction: column; gap: .55rem; }
  .muted { color: var(--muted); font-size: .88rem; }

  .matcher-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 80; }
  .forge-drawer {
    position: fixed; top: 0; right: 0; bottom: 0; width: min(400px, 100vw); z-index: 90;
    background: var(--card); border-left: 1px solid var(--border-2); box-shadow: var(--shadow);
    display: flex; flex-direction: column;
  }
  .fd-head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.1rem; border-bottom: 1px solid var(--border); font-weight: 600; color: var(--text); }
  .fd-body { padding: 1rem 1.1rem; }
  .x { background: transparent; border: 0; color: var(--muted); font-size: 1rem; cursor: pointer; }
  .x:hover { color: var(--text); filter: none; }
</style>
