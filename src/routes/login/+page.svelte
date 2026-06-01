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
  // step 2: the 6-digit code the user pastes from their inbox
  let code = $state('');
  let verifying = $state(false);

  async function signIn(e: Event) {
    e.preventDefault();
    error = '';
    if (!supabaseConfigured) {
      error = 'Supabase is not configured yet.';
      return;
    }
    loading = true;
    authError.set(null);
    // Invite-only: only request a code if this email is on the member list.
    // Stops non-invited emails from ever creating an auth user / signup email.
    const { data: isInvited, error: chkErr } = await supabase.rpc('is_email_invited', { p_email: email });
    if (chkErr) { loading = false; error = chkErr.message; return; }
    if (!isInvited) {
      loading = false;
      error = "This email isn't on the invite list. Ask a community admin to invite you first.";
      return;
    }
    // No emailRedirectTo → Supabase emails the {{ .Token }} verification code
    // instead of a single-use magic link (scanner-proof for enterprise inboxes).
    const { error: err } = await supabase.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: false }
    });
    loading = false;
    if (err) error = err.message;
    else sent = true;
  }

  async function verify(e: Event) {
    e.preventDefault();
    error = '';
    authError.set(null);
    const token = code.trim();
    if (token.length < 6) { error = 'Enter the 6-digit code from your email.'; return; }
    verifying = true;
    const { error: err } = await supabase.auth.verifyOtp({ email, token, type: 'email' });
    verifying = false;
    if (err) {
      error = 'That code is invalid or has expired. Request a new one.';
      return;
    }
    // verifyOtp establishes the session; the layout's auth listener takes over.
  }

  function restart() {
    sent = false;
    code = '';
    error = '';
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
        {$t("Membership is invite-only. Enter the email you were invited with — we'll send a verification code.")}
      </p>
    {/if}

    {#if $authError}
      <p class="neg" style="font-size:.85rem; border:1px solid var(--down); border-radius:8px; padding:.5rem .7rem;">{$t($authError)}</p>
    {/if}

    {#if sent}
      <p class="muted" style="margin-top:-.25rem;">
        {$t('We emailed a 6-digit code to {email}. Enter it below to sign in.', { email })}
      </p>
      <form class="stack" onsubmit={verify}>
        <input
          type="text"
          inputmode="numeric"
          autocomplete="one-time-code"
          maxlength="6"
          placeholder="123456"
          bind:value={code}
          style="letter-spacing:.4em; font-size:1.2rem; text-align:center;"
          required
        />
        <button type="submit" disabled={verifying}>
          {verifying ? $t('Verifying…') : $t('Verify & sign in')}
        </button>
      </form>
      <button class="linkish" onclick={restart} style="background:none; border:none; color:var(--muted); font-size:.82rem; cursor:pointer; padding:0; text-align:left;">
        {$t('Use a different email')}
      </button>
    {:else}
      <form class="stack" onsubmit={signIn}>
        <input
          type="email"
          placeholder="you@university.edu"
          bind:value={email}
          required
        />
        <button type="submit" disabled={loading}>
          {loading ? $t('Sending…') : $t('Send verification code')}
        </button>
      </form>
    {/if}
    {#if error}<p class="neg" style="font-size:.85rem;">{$t(error)}</p>{/if}
  </div>
</div>
