<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  type Pending = { id: string; full_name: string; email: string; affiliation: string | null };
  type Position = { id: string; name: string };

  let pending = $state<Pending[]>([]);
  let positions = $state<Position[]>([]);
  let loading = $state(true);
  let error = $state('');

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
    error = '';
    if (!fullName.trim() || !email.trim()) { error = get(t)('Name and email are required.'); return; }
    const { data, error: err } = await supabase
      .from('member')
      .insert({ full_name: fullName.trim(), email: email.trim(), affiliation: affiliation || null, status: 'invited' })
      .select('id')
      .single();
    if (err) { error = err.message; return; }
    if (positionId && data) {
      await supabase.from('member_position').insert({ member_id: data.id, position_id: positionId });
    }
    fullName = ''; email = ''; affiliation = ''; positionId = '';
    await load();
  }
</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Invite members')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('Pre-create a member by email. When they sign in with that email via magic link, their account binds to this record automatically. Anyone not pre-created here cannot get in.')}
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}

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
    <button onclick={invite}>{$t('Invite')}</button>
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
