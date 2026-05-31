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
  <div class="card stack">
    <h1>Sign in</h1>
    <p class="muted" style="margin-top:-.5rem;">
      Membership is invite-only. Enter the email you were invited with — we'll send a magic link.
    </p>

    {#if sent}
      <p class="badge">Check your inbox for the sign-in link.</p>
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
    {#if error}<p style="color:#b91c1c;">{error}</p>{/if}
  </div>
</div>
