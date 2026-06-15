<script lang="ts">
  // Staged release flow: compose release notes, PICK the preview reviewers from
  // the member list, send to them first, then send to everyone. Both stages call
  // the `announce-release` edge function; it only mails ids that are inside the
  // gated release_recipients('all') set, so it can't reach a non-member.
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { confirm } from '$lib/confirm';
  import { toast } from '$lib/toast';
  import Icon from '$lib/Icon.svelte';

  type Cand = { member_id: string; full_name: string; email: string };
  let members = $state<Cand[]>([]);
  let picked = $state<Set<string>>(new Set());
  let q = $state('');
  let loading = $state(true);
  let sending = $state<'' | 'preview' | 'all'>('');
  let result = $state('');

  let subject = $state("What's new — fixes from your feedback");
  let bodyText = $state(`Thank you for all the issues you filed — almost everything below came straight from your reports. Here's what changed:

- The browser Back button works again.
- Assigning people now confirms first, tells you the exact missing skill if someone doesn't qualify, and every seated person can be removed or replaced from the team.
- Changing a project's status asks before it commits; finishing a project asks twice.
- Setting someone's monthly hours now has a clear Save button and a confirmation.
- One skill scale everywhere — Learning, Independent, Lead. The old badge levels are retired.
- You can now archive a project or a person added by mistake, and remove a posted role.
- The Guide is rewritten around the three roles: Chapter Officer, Working Group Leader, First Author.
- The mobile layout no longer overlaps titles and badges, and the notifications bell is now a clearly visible button.
- A person's available time is shown as one consistent number everywhere, separated from compute/data/funding resources.
- When you edit your own card (skills, level, hours), the change is now sent to your chapter officer to approve — so your roster stays accurate.

Please keep the feedback coming — this is built by your suggestions, one round at a time.`);

  const filtered = $derived(
    members.filter((m) => {
      const s = q.trim().toLowerCase();
      return !s || m.full_name.toLowerCase().includes(s) || (m.email ?? '').toLowerCase().includes(s);
    })
  );

  async function loadMembers() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    // gated list (manage_members) — also the 'everyone' audience
    const { data } = await supabase.rpc('release_recipients', { p_audience: 'all' });
    members = ((data as Cand[]) ?? []).filter((m) => m.email);
    loading = false;
  }
  onMount(loadMembers);

  function toggle(id: string) {
    const s = new Set(picked);
    s.has(id) ? s.delete(id) : s.add(id);
    picked = s;
  }

  function toHtml(text: string): string {
    const blocks = text.trim().split(/\n\s*\n/);
    return blocks.map((b) => {
      const lines = b.split('\n');
      if (lines.every((l) => l.trim().startsWith('- '))) {
        const items = lines.map((l) => `<li style="margin:4px 0;">${esc(l.replace(/^\s*-\s+/, ''))}</li>`).join('');
        return `<ul style="margin:8px 0; padding-left:20px;">${items}</ul>`;
      }
      return `<p style="margin:12px 0;">${esc(b).replace(/\n/g, '<br>')}</p>`;
    }).join('');
  }
  function esc(s: string) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  async function send(stage: 'preview' | 'all') {
    if (!subject.trim() || !bodyText.trim()) { toast.error($t('Add a subject and body first.')); return; }
    const n = stage === 'preview' ? picked.size : members.length;
    if (stage === 'preview' && n === 0) { toast.error($t('Pick at least one reviewer.')); return; }
    const ok = await confirm({
      title: stage === 'preview'
        ? $t('Send the preview to {n} reviewer(s)?', { n })
        : $t('Send to all {n} member(s)?', { n }),
      body: stage === 'all'
        ? $t('This emails every member. Send the preview first and make sure it reads right.')
        : $t('Only the people you picked get this — your chance to check it before everyone does.'),
      confirmLabel: stage === 'preview' ? $t('Send preview') : $t('Send to everyone'),
      tone: stage === 'all' ? 'danger' : 'default'
    });
    if (!ok) return;
    sending = stage; result = '';
    const body = stage === 'preview'
      ? { recipient_ids: [...picked], subject: subject.trim(), body_html: toHtml(bodyText) }
      : { audience: 'all', subject: subject.trim(), body_html: toHtml(bodyText) };
    const { data, error } = await supabase.functions.invoke('announce-release', { body });
    sending = '';
    if (error) { toast.error(error.message); return; }
    const d = data as any;
    if (d?.error) { toast.error(d.error); return; }
    if (d?.email_error) { toast.error(d.email_error); return; }
    const sent = d?.sent ?? 0;
    result = $t('Sent to {sent} of {total} ({audience}).', { sent, total: d?.total ?? sent, audience: stage });
    toast.success(result);
  }
</script>

<div class="stack">
  <h1>{$t('Release notes')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('Email a release to the reviewers you pick first, look it over, then send it to everyone. Two stages, on purpose.')}
  </p>

  <div class="card stack">
    <label class="fld"><span>{$t('Subject')}</span>
      <input bind:value={subject} />
    </label>
    <label class="fld"><span>{$t('Body')}</span>
      <textarea rows="13" bind:value={bodyText}></textarea>
      <span class="hint">{$t('Blank lines start a new paragraph; lines beginning with “- ” become bullets.')}</span>
    </label>
  </div>

  <div class="stages">
    <!-- stage 1: pick reviewers + send preview -->
    <div class="stage">
      <div class="stage-h"><span class="stage-n">1</span> {$t('Preview to reviewers')}</div>
      <p class="muted sm">{$t('Pick who previews it (e.g. Yuechen & Zhuoran).')}</p>
      <input class="pick-q" placeholder={$t('Search members…')} bind:value={q} />
      <div class="picker">
        {#if loading}
          <p class="muted sm">{$t('Loading…')}</p>
        {:else}
          {#each filtered as m (m.member_id)}
            <button type="button" class="prow" class:on={picked.has(m.member_id)} onclick={() => toggle(m.member_id)}>
              <span class="pcheck">{#if picked.has(m.member_id)}<Icon name="check" size={12} />{/if}</span>
              <span class="pname">{m.full_name}</span>
              <span class="pmail">{m.email}</span>
            </button>
          {/each}
          {#if !filtered.length}<p class="muted sm">{$t('No matching members.')}</p>{/if}
        {/if}
      </div>
      <button class="go" disabled={sending !== '' || picked.size === 0} onclick={() => send('preview')}>
        {sending === 'preview' ? $t('Sending…') : $t('Send preview')}<span class="cnt"> · {picked.size}</span>
      </button>
    </div>

    <!-- stage 2: send to everyone -->
    <div class="stage">
      <div class="stage-h"><span class="stage-n">2</span> {$t('Release to everyone')}</div>
      <p class="muted sm">{$t('Every member with an email. Do this once the reviewers are happy.')}</p>
      <button class="go danger" disabled={sending !== '' || loading} onclick={() => send('all')}>
        {sending === 'all' ? $t('Sending…') : $t('Send to everyone')}{#if !loading}<span class="cnt"> · {members.length}</span>{/if}
      </button>
    </div>
  </div>

  {#if result}<p class="ok">{result}</p>{/if}
</div>

<style>
  .fld { display: flex; flex-direction: column; gap: .3rem; }
  .fld span { font-size: .8rem; color: var(--muted); }
  .fld input, .fld textarea { padding: .5rem .6rem; border: 1px solid var(--border); border-radius: var(--r-sm);
    background: var(--bg); color: var(--text); font: inherit; }
  .fld textarea { resize: vertical; line-height: 1.5; }
  .hint { font-size: .74rem; color: var(--muted); }
  .stages { display: grid; grid-template-columns: 1.3fr 1fr; gap: .8rem; align-items: start; }
  @media (max-width: 640px) { .stages { grid-template-columns: 1fr; } }
  .stage { border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card); padding: .9rem 1rem; display: flex; flex-direction: column; gap: .45rem; }
  .stage-h { font-weight: 700; display: flex; align-items: center; gap: .5rem; }
  .stage-n { display: inline-flex; align-items: center; justify-content: center; width: 1.4rem; height: 1.4rem;
    border-radius: 50%; background: var(--accent); color: #fff; font-size: .8rem; }
  .sm { font-size: .8rem; margin: 0; }
  .pick-q { padding: .4rem .55rem; border: 1px solid var(--border); border-radius: var(--r-sm); background: var(--bg); color: var(--text); font: inherit; }
  .picker { display: flex; flex-direction: column; max-height: 13rem; overflow-y: auto; border: 1px solid var(--border); border-radius: var(--r-sm); }
  .prow { display: flex; align-items: center; gap: .5rem; padding: .4rem .55rem; background: none; border: none; border-bottom: 1px solid var(--border); cursor: pointer; text-align: left; color: var(--text); }
  .prow:last-child { border-bottom: none; }
  .prow:hover { background: var(--card-2); }
  .prow.on { background: var(--accent-soft); }
  .pcheck { width: 1.1rem; height: 1.1rem; flex: none; border: 1px solid var(--border-2); border-radius: 3px; display: inline-flex; align-items: center; justify-content: center; color: var(--accent); }
  .prow.on .pcheck { border-color: var(--accent); }
  .pname { font-weight: 600; font-size: .9rem; }
  .pmail { font-size: .78rem; color: var(--muted); margin-left: auto; }
  .go { align-self: flex-start; margin-top: .2rem; border: none; background: var(--accent); color: #fff;
    border-radius: var(--r-sm); padding: .5rem .9rem; font: inherit; font-weight: 700; cursor: pointer; }
  .go.danger { background: var(--down); }
  .go:disabled { opacity: .55; cursor: default; }
  .cnt { font-weight: 500; opacity: .85; }
  .ok { color: var(--up); font-weight: 600; }
</style>
