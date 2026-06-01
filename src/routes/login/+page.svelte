<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';

  let email = $state('');
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
  <div class="row" style="justify-content:center; gap:.55rem; margin-bottom:.25rem;">
    <span class="brand" style="font-size:1.2rem;"><span class="dot"></span>The&nbsp;Fin&nbsp;AI <span class="muted" style="font-weight:500;">· Stater</span></span>
  </div>
  <div class="card stack">
    <h1 style="margin-bottom:0;">Sign in</h1>
    <p class="muted" style="margin-top:-.5rem;">
      Membership is invite-only. Enter the email you were invited with — we'll send a magic link.
    </p>

    {#if sent}
      <p class="badge pos">Check your inbox for the sign-in link.</p>
    {:else}
      <form class="stack" onsubmit={signIn}>
        <input
          type="email"
          placeholder="you@university.edu"
          bind:value={email}
          required
        />
        <button type="submit" disabled={loading}>
          {loading ? 'Sending…' : 'Send magic link'}
        </button>
      </form>
    {/if}
    {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}
  </div>
</div>
