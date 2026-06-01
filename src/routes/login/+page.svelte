<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { authError } from '$lib/session';
  import { t } from '$lib/i18n';
  import LangSwitcher from '$lib/LangSwitcher.svelte';

  // An invitation letter links here with ?email=…&invited=1 so we can greet
  // the new member and pre-fill their address before they request the link.
  const params = new URLSearchParams(typeof window !== 'undefined' ? window.location.search : '');
  let email = $state(params.get('email') ?? '');
  const invited = params.get('invited') === '1';
  let sent = $state(false);
  let error = $state('');
  let loading = $state(false);

  async function signIn(e: Event) {
    e.preventDefault();
    error = '';
    if (!supabaseConfigured) {
      error = 'Supabase is not configured yet.';
      return;
    }
    loading = true;
    authError.set(null);
    // Invite-only: only request a magic link if this email is on the member list.
    // Stops non-invited emails from ever creating an auth user / signup email.
    const { data: invited, error: chkErr } = await supabase.rpc('is_email_invited', { p_email: email });
    if (chkErr) { loading = false; error = chkErr.message; return; }
    if (!invited) {
      loading = false;
      error = "This email isn't on the invite list. Ask a community admin to invite you first.";
      return;
    }
    const { error: err } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: window.location.origin }
    });
    loading = false;
    if (err) error = err.message;
    else sent = true;
  }
</script>

<div class="stack" style="max-width: 420px; margin: 4rem auto;">
  <div class="row" style="justify-content:space-between; gap:.55rem; margin-bottom:.25rem;">
    <span class="brand" style="font-size:1.2rem;"><span class="dot"></span>The&nbsp;Fin&nbsp;AI <span class="muted" style="font-weight:500;">· Stater</span></span>
    <LangSwitcher />
  </div>
  <div class="card stack">
    <h1 style="margin-bottom:0;">{invited ? $t('Welcome to The Fin AI') : $t('Sign in')}</h1>
    {#if invited}
      <p class="muted" style="margin-top:-.5rem;">
        {$t("You've been invited! Confirm your email below and we'll send a secure one-time sign-in link — no password needed.")}
      </p>
    {:else}
      <p class="muted" style="margin-top:-.5rem;">
        {$t("Membership is invite-only. Enter the email you were invited with — we'll send a magic link.")}
      </p>
    {/if}

    {#if $authError}
      <p class="neg" style="font-size:.85rem; border:1px solid var(--down); border-radius:8px; padding:.5rem .7rem;">{$t($authError)}</p>
    {/if}

    {#if sent}
      <p class="badge pos">{$t('Check your inbox for the sign-in link.')}</p>
    {:else}
      <form class="stack" onsubmit={signIn}>
        <input
          type="email"
          placeholder="you@university.edu"
          bind:value={email}
          required
        />
        <button type="submit" disabled={loading}>
          {loading ? $t('Sending…') : $t('Send magic link')}
        </button>
      </form>
    {/if}
    {#if error}<p class="neg" style="font-size:.85rem;">{$t(error)}</p>{/if}
  </div>
</div>
