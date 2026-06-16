// First-run "quest" — a game-like, role-aware guided onboarding. The landing is a
// data table full of invented concepts (STR, needs, cards); a first-timer from a
// Google Doc doesn't know what to do. This walks them through their first REAL
// task, one step at a time, teaching each concept where it's met. One-time and
// skippable, so it never nags a returning user. (Answers "do they know how to
// operate it the moment they log in?" — they didn't.)
import { writable, get } from 'svelte/store';
import { supabase } from '$lib/supabase';
import { member, officerUnits, capabilities } from '$lib/session';

export type QuestStep = {
  key: string;
  label: string; // short imperative — what to do
  why: string;   // plain-language reason it matters (teaches the concept)
  href: string;  // where the action lives
  cta: string;   // button label
};
export type Quest = { id: string; title: string; subtitle: string; steps: QuestStep[]; auto: boolean };

type Saved = { questId: string; step: number; status: Status; baseline: Record<string, number> };
type Status = 'active' | 'done' | 'skipped';

const KEY = (mid: string) => `onboarding_v1_${mid}`;

export const quest = writable<Quest | null>(null);
export const questStep = writable(0);
export const questStatus = writable<Status | null>(null);

let baseline: Record<string, number> = {};
let chapterUnitIds: string[] = [];
let wgUnitIds: string[] = [];
let initialized = false;

// ---- the four role quests (data) ----
const CHAPTER_QUEST: Quest = {
  id: 'chapter',
  title: 'Onboard your first researcher',
  subtitle: "You're a Chapter Officer — your job is keeping your people ready to be staffed. Let's add one.",
  auto: true, // chapter steps auto-complete when the real action is detected
  steps: [
    { key: 'add', label: 'Add a researcher to your chapter', why: 'Adding a person creates a “card” you manage on their behalf — like a row in your old shared doc — until they sign in and claim it.', href: '/people', cta: 'Go to People' },
    { key: 'capacity', label: 'Set how many hours a month they can give', why: 'Their available time is what lets them be matched onto a project that needs them.', href: '/people', cta: 'Open a person' },
    { key: 'staff', label: 'Put them on a project that needs them', why: 'This is the whole point: a working group posts a NEED, and you supply a person from your chapter to fill it.', href: '/projects', cta: 'Open Projects' }
  ]
};
const WG_QUEST: Quest = {
  id: 'wg',
  title: 'Take the lead on a project',
  subtitle: "You're a Working-Group Leader — projects are already on the board. Your first move is to lead one, not start from scratch.",
  auto: true, // the "claim" step auto-completes when you take a lead seat
  steps: [
    { key: 'adopt', label: 'Take a project into your working group', why: 'Projects already exist here. Adopt one into your group (see “Projects looking for a working group”) — that sets it under you and unlocks editing it and posting its needs.', href: '/projects', cta: 'Open Projects' },
    { key: 'need', label: 'Post a role your project still needs', why: 'You post the demand (e.g. an annotator); a Chapter Officer fills it with someone from their chapter — you don’t hire directly.', href: '/projects', cta: 'Open your project' },
    { key: 'advance', label: 'Move the project forward', why: 'As work lands and the project finishes, STR (contribution credit) settles and splits among everyone who contributed.', href: '/projects', cta: 'Open your project' }
  ]
};
const MEMBER_QUEST: Quest = {
  id: 'member',
  title: 'Find your work',
  subtitle: 'Welcome — here’s how to see what’s waiting for you and keep your record current.',
  auto: false,
  steps: [
    { key: 'tasks', label: 'Open “My tasks”', why: 'Everything assigned to you lives here — open it from the account menu (top-right).', href: '/my', cta: 'Open My tasks' },
    { key: 'state', label: 'Move one of your tasks along', why: 'Marking work started/done keeps your team’s living record honest.', href: '/my', cta: 'Open My tasks' },
    { key: 'time', label: 'Update your available hours', why: 'Your availability lets officers staff you. Your edits go to your officer for review first.', href: '/my', cta: 'Open your profile' }
  ]
};
const PRESIDENT_QUEST: Quest = {
  id: 'president',
  title: 'Make your first decision',
  subtitle: 'You hold review authority — here’s where decisions wait and what approving one does.',
  auto: false,
  steps: [
    { key: 'inbox', label: 'Open the review inbox', why: 'Resources, settlements, milestones and unit applications wait here for a yes/no.', href: '/admin/forge-queue', cta: 'Open the inbox' },
    { key: 'decide', label: 'Approve or reject one item', why: 'Approving makes the submission real (e.g. a resource becomes offerable, a settlement pays out STR).', href: '/admin/forge-queue', cta: 'Open the inbox' }
  ]
};

function pickQuest(): Quest | null {
  const units = get(officerUnits);
  const caps = get(capabilities);
  if (units.some((u) => u.kind === 'chapter')) return CHAPTER_QUEST;
  if (units.some((u) => u.kind === 'working_group')) return WG_QUEST;
  if (caps.has('manage_stater') || caps.has('manage_members') || caps.has('review_skillcard')) return PRESIDENT_QUEST;
  return MEMBER_QUEST;
}

// the metrics an auto quest watches, captured at start (baseline) and re-read on
// each navigation; a step completes when its metric grows past the baseline.
async function questCounts(q: Quest | null): Promise<Record<string, number>> {
  const m = get(member);
  if (q?.id === 'chapter') {
    if (!chapterUnitIds.length) return { roster: 0, withHours: 0, staffed: 0 };
    const { data: roster } = await supabase.from('member').select('id, monthly_hours').in('home_unit_id', chapterUnitIds);
    const rows = (roster as { id: string; monthly_hours: number | null }[]) ?? [];
    const withHours = rows.filter((r) => r.monthly_hours != null).length;
    let staffed = 0;
    if (rows.length) {
      const { count } = await supabase.from('work_commitment').select('id', { count: 'exact', head: true }).in('member_id', rows.map((r) => r.id));
      staffed = count ?? 0;
    }
    return { roster: rows.length, withHours, staffed };
  }
  if (q?.id === 'wg') {
    // "adopted a project" = a project now belongs to your working group
    if (!wgUnitIds.length) return { owned: 0 };
    const { count } = await supabase.from('project').select('id', { count: 'exact', head: true }).in('org_unit_id', wgUnitIds);
    return { owned: count ?? 0 };
  }
  return {};
}

function persist() {
  const m = get(member); if (!m) return;
  const saved: Saved = { questId: get(quest)?.id ?? '', step: get(questStep), status: get(questStatus) ?? 'active', baseline };
  try { localStorage.setItem(KEY(m.id), JSON.stringify(saved)); } catch { /* ignore */ }
}

export function advance() {
  const q = get(quest); if (!q) return;
  const next = get(questStep) + 1;
  if (next >= q.steps.length) { questStatus.set('done'); }
  else questStep.set(next);
  persist();
}
export function skip() { questStatus.set('skipped'); persist(); }
export function dismiss() { questStatus.set('done'); persist(); }

// auto-advance the chapter quest when the real action is detected (the satisfying
// "I did it!" beat). Called on route changes from the layout.
export async function refresh() {
  const q = get(quest);
  if (!q || !q.auto || get(questStatus) !== 'active') return;
  const cur = await questCounts(q);
  const i = get(questStep);
  let hit = false;
  if (q.id === 'chapter') {
    hit = (i === 0 && (cur.roster ?? 0) > (baseline.roster ?? 0))
      || (i === 1 && (cur.withHours ?? 0) > (baseline.withHours ?? 0))
      || (i === 2 && (cur.staffed ?? 0) > (baseline.staffed ?? 0));
  } else if (q.id === 'wg') {
    hit = i === 0 && (cur.owned ?? 0) > (baseline.owned ?? 0);
  }
  if (hit) advance();
}

export async function initOnboarding() {
  if (initialized) return;
  const m = get(member); if (!m) return;
  const q = pickQuest(); if (!q) return;
  initialized = true;
  chapterUnitIds = get(officerUnits).filter((u) => u.kind === 'chapter').map((u) => u.unit_id);
  wgUnitIds = get(officerUnits).filter((u) => u.kind === 'working_group').map((u) => u.unit_id);

  let raw: string | null = null;
  try { raw = localStorage.getItem(KEY(m.id)); } catch { /* ignore */ }
  if (raw) {
    const s = JSON.parse(raw) as Saved;
    if (s.status !== 'active') { questStatus.set(s.status); return; } // already finished/skipped — stay hidden
    baseline = s.baseline ?? {};
    quest.set(q); questStep.set(Math.min(s.step, q.steps.length - 1)); questStatus.set('active');
  } else {
    baseline = q.auto ? await questCounts(q) : {};
    quest.set(q); questStep.set(0); questStatus.set('active');
    persist();
  }
  refresh();
}
