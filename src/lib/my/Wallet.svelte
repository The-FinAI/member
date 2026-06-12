<script lang="ts">
  // BUILD PLAN P4 — the quiet contribution wallet (PRD §4.5). STR is legible
  // where it's real: accruing (locked in live projects) vs settled (paid out,
  // spendable), with a one-tap "how it's computed". Quiet by default.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import { t } from '$lib/i18n';

  let settled = $state(0);     // liquid balance
  let accruing = $state(0);    // nominal still locked in live projects
  let loading = $state(true);
  let how = $state(false);

  async function load() {
    const me = $member?.id;
    if (!supabaseConfigured || !me) { loading = false; return; }
    loading = true;
    const [{ data: bal }, { data: nom }] = await Promise.all([
      supabase.from('stater_balance').select('balance').eq('owner_member_id', me).maybeSingle(),
      supabase.from('stater_project_member_nominal').select('nominal').eq('member_id', me)
    ]);
    settled = Number((bal as any)?.balance ?? 0);
    accruing = ((nom as any[]) ?? []).reduce((s, r) => s + (Number(r.nominal) || 0), 0);
    loading = false;
  }
  $effect(() => { $member; load(); });
</script>

{#if !loading && ($member)}
  <section class="wal">
    <div class="wal-row">
      <div class="wal-fig">
        <span class="wal-n accr">{accruing.toLocaleString()}</span>
        <span class="wal-l">{$t('accruing')} <span class="wal-dim">{$t('(in live projects)')}</span></span>
      </div>
      <span class="wal-arrow">→</span>
      <div class="wal-fig">
        <span class="wal-n setl">{settled.toLocaleString()}</span>
        <span class="wal-l">{$t('settled')} <span class="wal-dim">{$t('(spendable)')}</span></span>
      </div>
      <button class="wal-how" onclick={() => (how = !how)}>{$t('How is this computed?')}</button>
    </div>
    {#if how}
      <p class="wal-help">{$t('Your committed hours and resources mint STR as you contribute (accruing, locked). When a project finishes and is settled, its pool pays out as settled STR you can spend.')}</p>
    {/if}
  </section>
{/if}

<style>
  .wal { background: var(--card-bg, #fafafa); border: 1px solid var(--line, #eee); border-radius: var(--r-md); padding: .7rem .9rem; margin-bottom: 1.2rem; }
  .wal-row { display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; }
  .wal-fig { display: flex; flex-direction: column; }
  .wal-n { font-size: 1.4rem; font-weight: 700; line-height: 1; }
  .wal-n.accr { color: #b8860b; } .wal-n.setl { color: #2e7d4f; }
  .wal-l { font-size: .78rem; color: var(--muted, #777); margin-top: .15rem; }
  .wal-dim { color: var(--muted, #aaa); }
  .wal-arrow { color: var(--muted, #ccc); font-size: 1.2rem; }
  .wal-how { margin-left: auto; border: none; background: none; color: var(--accent, #6a7cff); cursor: pointer; font-size: .82rem; }
  .wal-help { font-size: .82rem; color: var(--muted, #777); margin: .5rem 0 0; max-width: 46rem; }
</style>
