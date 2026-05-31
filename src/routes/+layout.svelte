<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { session, member, capabilities, authReady } from '$lib/session';
  import { loadProfile, clearProfile, claimMembership } from '$lib/profile';
  import { theme, toggleTheme } from '$lib/theme';

  let { children } = $props();

  const PUBLIC_ROUTES = ['/login'];

  let balance = $state<number | null>(null);

  async function loadBalance(memberId: string) {
    const { data } = await supabase
      .from('stater_balance').select('balance').eq('owner_member_id', memberId).maybeSingle();
    balance = Number((data as { balance: number } | null)?.balance ?? 0);
  }

  $effect(() => { if ($member) loadBalance($member.id); else balance = null; });

  const navItems = [
    { href: '/projects', label: 'Projects' },
    { href: '/opportunities', label: 'Opportunities' },
    { href: '/members', label: 'Leaderboard' }
  ];
  function isActive(href: string, path: string) {
    return href === '/' ? path === '/' : path.startsWith(href);
  }

  let menuOpen = $state(false);
  function initials(name: string | undefined) {
    if (!name) return '·';
    const p = name.trim().split(/\s+/);
    return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toUpperCase() || '·';
  }
  function go(href: string) { menuOpen = false; goto(href); }

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

<header class="topbar">
  <div class="container row" style="justify-content: space-between; padding-block: .65rem; gap: 1rem;">
    <a href="/" class="brand">
      <span class="dot"></span>
      The&nbsp;Fin&nbsp;AI <span class="muted" style="font-weight:500;">· Stater</span>
    </a>

    <div class="row" style="gap: 1.1rem;">
      {#if $session}
        <nav class="row" style="gap: 1.1rem;">
          {#each navItems as n}
            <a href={n.href} class="navlink" class:active={isActive(n.href, $page.url.pathname)}>{n.label}</a>
          {/each}
          {#if canAdmin}
            <a href="/admin" class="navlink" class:active={isActive('/admin', $page.url.pathname)}>Admin</a>
          {/if}
        </nav>

        {#if balance !== null}
          <a href="/wallet" class="chip" title="Open your wallet">
            <span class="amt">{balance.toLocaleString()}</span> STR
          </a>
        {/if}
      {/if}

      <button class="icon-btn" onclick={toggleTheme} title="Toggle theme" aria-label="Toggle theme">
        {$theme === 'dark' ? '☀' : '☾'}
      </button>

      {#if $session}
        <div class="usermenu">
          <button class="avatar-btn" onclick={() => (menuOpen = !menuOpen)} title="Account" aria-label="Account menu" aria-haspopup="true" aria-expanded={menuOpen}>
            {initials($member?.full_name)}
          </button>
          {#if menuOpen}
            <div class="menu-backdrop" onclick={() => (menuOpen = false)} role="presentation"></div>
            <div class="menu">
              <div class="menu-head">
                <div class="mh-name">{$member?.full_name ?? 'Account'}</div>
                <div class="mh-mail">{$session.user.email}</div>
              </div>
              <div class="menu-sep"></div>
              <button class="menu-item" onclick={() => go('/profile')}><span class="mi-ico">⚙</span> Profile &amp; skills</button>
              <div class="menu-sep"></div>
              <button class="menu-item" onclick={signOut}><span class="mi-ico">⏻</span> Sign out</button>
            </div>
          {/if}
        </div>
      {/if}
    </div>
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
