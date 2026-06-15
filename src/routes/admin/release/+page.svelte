<script lang="ts">
  // Staged release flow: compose release notes, send to the PREVIEW reviewers
  // first (flagged members — Yuechen, Zhuoran), look it over, then send to
  // EVERYONE. Both stages call the `announce-release` edge function, which only
  // emails the list `release_recipients(audience)` returns (gated by
  // manage_members), so this can't be used to spam.
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { confirm } from '$lib/confirm';
  import { toast } from '$lib/toast';

  let previewCount = $state<number | null>(null);
  let allCount = $state<number | null>(null);
  let loading = $state(true);
  let sending = $state<'' | 'preview' | 'all'>('');
  let result = $state('');

  // prefilled with this release's notes — edit freely. Blank lines become
  // paragraphs; a line starting with "- " becomes a bullet.
  let subject = $state("What's new — fixes from your feedback");
  let bodyText = $state(`Thank you for all the issues you filed — almost everything below came straight from your reports. Here's what changed:

- The browser Back button works again.
- Assigning people now confirms first, tells you the exact missing skill if someone doesn't qualify, and every seated person can be removed or replaced from the team.
- Changing a project's status asks before it commits; finishing a project asks twice.
- Setting someone's monthly hours now has a clear Save button and a confirmation.
- One skill scale everywhere — Learning, Independent, Lead. The old badge levels are retired.
- You can now archive a project or a person added by mistake, and remove a posted role.
- The Guide is rewritten around the three roles: Chapter Officer, Working Group Leader, First Author.
- The mobile layout no longer overlaps titles and badges.

Please keep the feedback coming — this is built by your suggestions, one round at a time.`);

  async function loadCounts() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: pv }, { data: al }] = await Promise.all([
      supabase.rpc('release_recipients', { p_audience: 'preview' }),
      supabase.rpc('release_recipients', { p_audience: 'all' })
    ]);
    previewCount = (pv as any[])?.length ?? 0;
    allCount = (al as any[])?.length ?? 0;
    loading = false;
  }
  onMount(loadCounts);

  // plain text → simple HTML (paragraphs + bullet lists)
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

  async function send(audience: 'preview' | 'all') {
    if (!subject.trim() || !bodyText.trim()) { toast.error($t('Add a subject and body first.')); return; }
    const n = audience === 'preview' ? previewCount : allCount;
    const ok = await confirm({
      title: audience === 'preview'
        ? $t('Send the preview to {n} reviewer(s)?', { n: n ?? 0 })
        : $t('Send to all {n} member(s)?', { n: n ?? 0 }),
      body: audience === 'all'
        ? $t('This emails every member. Send the preview to reviewers first and make sure it reads right.')
        : $t('Only the flagged reviewers get this — your chance to check it before everyone does.'),
      confirmLabel: audience === 'preview' ? $t('Send preview') : $t('Send to everyone'),
      tone: audience === 'all' ? 'danger' : 'default'
    });
    if (!ok) return;
    sending = audience; result = '';
    const { data, error } = await supabase.functions.invoke('announce-release', {
      body: { audience, subject: subject.trim(), body_html: toHtml(bodyText) }
    });
    sending = '';
    if (error) { toast.error(error.message); return; }
    const d = data as any;
    if (d?.error) { toast.error(d.error); return; }
    if (d?.email_error) { toast.error(d.email_error); return; }
    const sent = d?.sent ?? 0;
    result = $t('Sent to {sent} of {total} ({audience}).', { sent, total: d?.total ?? sent, audience });
    toast.success(result);
  }
</script>

<div class="stack">
  <h1>{$t('Release notes')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('Email a release to the reviewers first, look it over, then send it to everyone. Two stages, on purpose.')}
  </p>

  <div class="card stack">
    <label class="fld"><span>{$t('Subject')}</span>
      <input bind:value={subject} />
    </label>
    <label class="fld"><span>{$t('Body')}</span>
      <textarea rows="14" bind:value={bodyText}></textarea>
      <span class="hint">{$t('Blank lines start a new paragraph; lines beginning with “- ” become bullets.')}</span>
    </label>
  </div>

  <div class="stages">
    <div class="stage">
      <div class="stage-h"><span class="stage-n">1</span> {$t('Preview to reviewers')}</div>
      <p class="muted sm">{$t('The flagged reviewers (set member.is_release_reviewer) — e.g. Yuechen & Zhuoran.')}</p>
      <button class="go" disabled={sending !== '' || loading} onclick={() => send('preview')}>
        {sending === 'preview' ? $t('Sending…') : $t('Send preview')}
        {#if !loading}<span class="cnt">· {previewCount ?? 0}</span>{/if}
      </button>
    </div>
    <div class="stage">
      <div class="stage-h"><span class="stage-n">2</span> {$t('Release to everyone')}</div>
      <p class="muted sm">{$t('Every member with an email. Do this once the reviewers are happy.')}</p>
      <button class="go danger" disabled={sending !== '' || loading} onclick={() => send('all')}>
        {sending === 'all' ? $t('Sending…') : $t('Send to everyone')}
        {#if !loading}<span class="cnt">· {allCount ?? 0}</span>{/if}
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
  .stages { display: grid; grid-template-columns: 1fr 1fr; gap: .8rem; }
  @media (max-width: 560px) { .stages { grid-template-columns: 1fr; } }
  .stage { border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card); padding: .9rem 1rem; display: flex; flex-direction: column; gap: .4rem; }
  .stage-h { font-weight: 700; display: flex; align-items: center; gap: .5rem; }
  .stage-n { display: inline-flex; align-items: center; justify-content: center; width: 1.4rem; height: 1.4rem;
    border-radius: 50%; background: var(--accent); color: #fff; font-size: .8rem; }
  .sm { font-size: .8rem; margin: 0; }
  .go { align-self: flex-start; margin-top: .2rem; border: none; background: var(--accent); color: #fff;
    border-radius: var(--r-sm); padding: .5rem .9rem; font: inherit; font-weight: 700; cursor: pointer; }
  .go.danger { background: var(--down); }
  .go:disabled { opacity: .55; cursor: default; }
  .cnt { font-weight: 500; opacity: .85; }
  .ok { color: var(--up); font-weight: 600; }
</style>
