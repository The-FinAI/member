<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import { member } from '$lib/session';
  import { PHASE2 } from '$lib/phase';

  type Pending = { id: string; full_name: string; email: string; affiliation: string | null };
  type Position = { id: string; name: string };

  let pending = $state<Pending[]>([]);
  let positions = $state<Position[]>([]);
  let loading = $state(true);
  let error = $state('');
  let notice = $state('');
  let sending = $state(false);

  let fullName = $state('');
  let email = $state('');
  let affiliation = $state('');
  let positionId = $state('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: m }, { data: p }] = await Promise.all([
      supabase.from('member').select('id, full_name, email, affiliation').eq('status', 'invited').order('full_name'),
      supabase.from('position').select('id, name').order('rank')
    ]);
    pending = (m as Pending[]) ?? [];
    positions = (p as Position[]) ?? [];
    loading = false;
  }

  onMount(load);

  async function invite() {
    error = ''; notice = '';
    if (!fullName.trim() || !email.trim()) { error = get(t)('Name and email are required.'); return; }
    const targetEmail = email.trim();
    sending = true;
    // The edge function inserts the member with the caller's JWT (so the same
    // RLS that gates the member table authorises this) and then emails the
    // invitation letter via Resend.
    const { data, error: err } = await supabase.functions.invoke('invite-member', {
      body: {
        full_name: fullName.trim(),
        email: targetEmail,
        affiliation: affiliation || null,
        position_id: positionId || null,
        inviter_name: get(member)?.full_name ?? null
      }
    });
    sending = false;
    if (err) { error = err.message; return; }
    if ((data as any)?.error) { error = (data as any).error; return; }
    if ((data as any)?.email_sent === false) {
      notice = get(t)('Member added, but the invitation email could not be sent. You can resend later.');
    } else {
      notice = get(t)('Invitation sent to {email} 🎉', { email: targetEmail });
    }
    fullName = ''; email = ''; affiliation = ''; positionId = '';
    await load();
  }
</script>

<div class="stack">
  <h1>{PHASE2 ? $t('Invite members') : $t('Invite officers')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {#if PHASE2}
      {$t('Add a member by email and we send them a branded invitation letter with a sign-in link. Their account binds to this record the first time they sign in. Anyone not added here cannot get in.')}
    {:else}
      {$t('Phase 1 is officers only. Invite chapter chairs, secretaries and working-group leaders here — give each one an officer position so they can forge cards and claim projects. Ordinary researchers are not invited yet; their officers forge cards for them instead. Anyone not added here cannot sign in.')}
    {/if}
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}
  {#if notice}<p style="color:var(--up);">{notice}</p>{/if}

  <div class="card row" style="align-items:flex-end;">
    <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.78rem;">{$t('Full name')}</span><input bind:value={fullName} /></label>
    <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.78rem;">{$t('Email')}</span><input type="email" bind:value={email} /></label>
    <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.78rem;">{$t('Affiliation')}</span><input bind:value={affiliation} /></label>
    <label class="stack" style="gap:.2rem;">
      <span class="muted" style="font-size:.78rem;">{$t('Position')}</span>
      <select bind:value={positionId}>
        <option value="">{$t('— none —')}</option>
        {#each positions as p}<option value={p.id}>{p.name}</option>{/each}
      </select>
    </label>
    <button onclick={invite} disabled={sending}>{sending ? $t('Sending…') : $t('Invite')}</button>
  </div>

  <div class="card">
    <h2>{$t('Pending (not yet signed in)')}</h2>
    {#if loading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if pending.length === 0}
      <p class="muted">{$t('No pending invites.')}</p>
    {:else}
      <table>
        <thead><tr><th>{$t('Name')}</th><th>{$t('Email')}</th><th>{$t('Affiliation')}</th></tr></thead>
        <tbody>
          {#each pending as m}
            <tr><td>{m.full_name}</td><td>{m.email}</td><td>{m.affiliation ?? '—'}</td></tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
