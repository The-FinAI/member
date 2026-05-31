<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { session, member, capabilities, authReady } from '$lib/session';
  import { loadProfile, clearProfile, claimMembership } from '$lib/profile';

  let { children } = $props();

  const PUBLIC_ROUTES = ['/login'];

  onMount(() => {
    if (!supabaseConfigured) {
      authReady.set(true);
      return;
    }

    // onAuthStateChange fires INITIAL_SESSION on subscribe (covers reload) and
    // SIGNED_IN on login. Its callback runs while supabase-js holds the auth
    // lock, so any supabase call awaited *inside* it deadlocks every later
    // query. Defer the work out of the lock with setTimeout.
    const { data: sub } = supabase.auth.onAuthStateChange((e, s) => {
      session.set(s);
      setTimeout(async () => {
        if (!s) {
          clearProfile();
        } else if (e === 'SIGNED_IN' || e === 'INITIAL_SESSION') {
          if (e === 'SIGNED_IN') await claimMembership();
          await loadProfile(s.user.id);
        }
        authReady.set(true);
      }, 0);
    });
    return () => sub.subscription.unsubscribe();
  });

  // route guard
  $effect(() => {
    if (!$authReady || !supabaseConfigured) return;
    const path = $page.url.pathname;
    const isPublic = PUBLIC_ROUTES.some((p) => path.startsWith(p));
    if (!$session && !isPublic) goto('/login');
    if ($session && isPublic) goto('/');
  });

  async function signOut() {
    await supabase.auth.signOut();
    goto('/login');
  }

  const canAdmin = $derived(
    $capabilities.has('manage_taxonomy') ||
      $capabilities.has('manage_members') ||
      $capabilities.has('edit_any_project')
  );
</script>

<header style="background: var(--navy); color: #fff;">
  <div class="container row" style="justify-content: space-between; padding-block: .8rem;">
    <a href="/" style="color:#fff; font-family: Newsreader, serif; font-size:1.1rem; font-weight:600;">
      The&nbsp;Fin&nbsp;AI · Community
    </a>
    {#if $session}
      <nav class="row" style="gap: 1rem;">
        <a href="/projects" style="color:#cbd5e1;">Projects</a>
        <a href="/opportunities" style="color:#cbd5e1;">Opportunities</a>
        <a href="/members" style="color:#cbd5e1;">Members</a>
        <a href="/profile" style="color:#cbd5e1;">Profile</a>
        {#if canAdmin}<a href="/admin" style="color:#cbd5e1;">Admin</a>{/if}
        <button class="ghost" style="color:#fff;border-color:#475569;" onclick={signOut}>Sign out</button>
      </nav>
    {/if}
  </div>
</header>

<main class="container">
  {#if !supabaseConfigured}
    <p class="banner">
      Supabase is not configured. Copy <code>.env.example</code> to <code>.env</code> and add your
      project URL + anon key, then restart the dev server. Pages render but data calls are disabled.
    </p>
  {/if}
  {#if supabaseConfigured && $authReady && $session && !$member}
    <p class="banner">
      You're signed in as <strong>{$session.user.email}</strong>, but this email isn't linked to a
      membership. Access is invite-only — please ask an admin to invite you.
    </p>
  {/if}
  {@render children()}
</main>
