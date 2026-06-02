<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { session, member, capabilities, officerUnits, actingAs, authReady, authError } from '$lib/session';
  import { loadProfile, clearProfile, claimMembership } from '$lib/profile';
  import { theme, toggleTheme } from '$lib/theme';
  import { t } from '$lib/i18n';
  import LangSwitcher from '$lib/LangSwitcher.svelte';
  import LaunchBanner from '$lib/LaunchBanner.svelte';
  import NavIcon from '$lib/NavIcon.svelte';

  let { children } = $props();

  // PUBLIC_ROUTES: only valid when signed OUT — a signed-in user is bounced away
  // (e.g. /login). OPEN_ROUTES: reachable by anyone, no redirect either way
  // (e.g. /guide, so prospective members can read it before being invited).
  const PUBLIC_ROUTES = ['/login'];
  const OPEN_ROUTES = ['/guide'];

  let balance = $state<number | null>(null);

  async function loadBalance(memberId: string) {
    const { data } = await supabase
      .from('stater_balance').select('balance').eq('owner_member_id', memberId).maybeSingle();
    balance = Number((data as { balance: number } | null)?.balance ?? 0);
  }

  $effect(() => { if ($member) loadBalance($member.id); else balance = null; });

  // Primary sidebar nav. `icon` keys map to NavIcon. Grouped: a workspace block
  // (entities), then a reference block; officer/admin entries appended below.
  const navItems = [
    { href: '/', label: 'Home', icon: 'home' },
    { href: '/projects', label: 'Projects', icon: 'projects' },
    { href: '/opportunities', label: 'Opportunities', icon: 'market' },
    { href: '/members', label: 'People', icon: 'people' },
    { href: '/skills', label: 'Guild', icon: 'guild' },
    { href: '/units', label: 'Units', icon: 'units' },
    { href: '/guide', label: 'Guide', icon: 'guide' }
  ];
  function isActive(href: string, path: string) {
    return href === '/' ? path === '/' : path.startsWith(href);
  }

  let menuOpen = $state(false);
  let sidebarOpen = $state(false);   // mobile drawer
  function initials(name: string | undefined) {
    if (!name) return '·';
    const p = name.trim().split(/\s+/);
    return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toUpperCase() || '·';
  }
  function go(href: string) { menuOpen = false; sidebarOpen = false; goto(href); }
  function navTo(href: string) { sidebarOpen = false; goto(href); }

  // If a magic link lands here with an error (single-use link already consumed
  // by an email scanner, expired, etc.), Supabase redirects back with the
  // reason in the URL hash/query. Capture it BEFORE the route guard sends us to
  // /login and discards the hash, so the user sees *why* instead of a silent
  // bounce. Returns true when an auth error was present.
  function captureAuthError(): boolean {
    if (typeof window === 'undefined') return false;
    const hp = new URLSearchParams(window.location.hash.replace(/^#/, ''));
    const qp = new URLSearchParams(window.location.search);
    const code = hp.get('error_code') || qp.get('error_code');
    const desc = hp.get('error_description') || qp.get('error_description');
    const err = hp.get('error') || qp.get('error');
    if (!err && !code && !desc) return false;
    authError.set(
      code === 'otp_expired'
        ? 'This sign-in link has expired or was already used. Please request a new one below.'
        : desc || 'Sign-in failed. Please request a new link below.'
    );
    // strip the error params so they don't linger or get re-processed
    history.replaceState(null, '', window.location.pathname);
    return true;
  }

  onMount(() => {
    if (!supabaseConfigured) {
      authReady.set(true);
      return;
    }

    captureAuthError();

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
    const isOpen = OPEN_ROUTES.some((p) => path.startsWith(p));
    if (!$session && !isPublic && !isOpen) goto('/login');
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
  // chapter officers get a "My chapter" entry (cards belong to chapters)
  const isChapterOfficer = $derived($officerUnits.some((u) => u.kind === 'chapter'));
</script>

<div class="shell" class:has-rail={!!$session}>
  {#if $session}
    <!-- mobile drawer backdrop -->
    {#if sidebarOpen}
      <div class="rail-backdrop" onclick={() => (sidebarOpen = false)} role="presentation"></div>
    {/if}

    <aside class="rail" class:open={sidebarOpen}>
      <a href="/" class="brand rail-brand" onclick={() => (sidebarOpen = false)}>
        <img src="/logo.png" alt="The Fin AI" class="brand-logo" />
        <span class="rail-brand-name">The&nbsp;Fin&nbsp;AI<small>Stater</small></span>
      </a>

      <nav class="rail-nav">
        {#each navItems as n}
          <a href={n.href} class="rail-link" class:active={isActive(n.href, $page.url.pathname)} onclick={() => (sidebarOpen = false)}>
            <NavIcon name={n.icon} /> <span>{$t(n.label)}</span>
          </a>
        {/each}

        {#if isChapterOfficer || canAdmin}
          <div class="rail-sep"></div>
          {#if isChapterOfficer}
            <a href="/my-chapter" class="rail-link" class:active={isActive('/my-chapter', $page.url.pathname)} onclick={() => (sidebarOpen = false)}>
              <NavIcon name="chapter" /> <span>{$t('My Chapter')}</span>
            </a>
          {/if}
          {#if canAdmin}
            <a href="/admin" class="rail-link" class:active={isActive('/admin', $page.url.pathname)} onclick={() => (sidebarOpen = false)}>
              <NavIcon name="admin" /> <span>{$t('Admin')}</span>
            </a>
          {/if}
        {/if}
      </nav>

      {#if balance !== null}
        <a href="/wallet" class="rail-wallet" onclick={() => (sidebarOpen = false)} title={$t('Open your wallet')}>
          <NavIcon name="wallet" />
          <span class="rw-label">{$t('Wallet')}</span>
          <span class="rw-amt"><span class="amt">{balance.toLocaleString()}</span> STR</span>
        </a>
      {/if}
    </aside>
  {/if}

  <div class="shell-main">
    <header class="topbar">
      <div class="topbar-inner">
        {#if $session}
          <button class="icon-btn rail-toggle" onclick={() => (sidebarOpen = !sidebarOpen)} aria-label={$t('Menu')} title={$t('Menu')}>☰</button>
        {/if}
        <a href="/" class="brand topbar-brand">
          <img src="/logo.png" alt="The Fin AI" class="brand-logo" />
          The&nbsp;Fin&nbsp;AI <span class="muted" style="font-weight:500;">· Stater</span>
        </a>

        <div class="row" style="gap: 1rem; margin-left:auto;">
          <LangSwitcher />
          <button class="icon-btn" onclick={toggleTheme} title={$t('Toggle theme')} aria-label={$t('Toggle theme')}>
            {$theme === 'dark' ? '☀' : '☾'}
          </button>
          {#if $session}
            <div class="usermenu">
              <button class="avatar-btn" onclick={() => (menuOpen = !menuOpen)} title={$t('Account')} aria-label={$t('Account menu')} aria-haspopup="true" aria-expanded={menuOpen}>
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
                  <button class="menu-item" onclick={() => go('/')}><span class="mi-ico">⚙</span> {$t('Portfolio & profile')}</button>
                  <div class="menu-sep"></div>
                  <button class="menu-item" onclick={signOut}><span class="mi-ico">⏻</span> {$t('Sign out')}</button>
                </div>
              {/if}
            </div>
          {/if}
        </div>
      </div>
    </header>

    <main class="container">
      {#if $session && $member}<LaunchBanner />{/if}
      {#if $actingAs}
        <div class="acting-banner">
          <span>{$t('Acting as card')} <strong>{$actingAs.full_name}</strong> — {$t('actions and STR apply to this card.')}</span>
          <button class="icon-btn" onclick={() => actingAs.set(null)}>{$t('Stop acting')}</button>
        </div>
      {/if}
      {#if !supabaseConfigured}
        <p class="banner">
          Supabase is not configured. Copy <code>.env.example</code> to <code>.env</code> and add your
          project URL + anon key, then restart the dev server. Pages render but data calls are disabled.
        </p>
      {/if}
      {#if supabaseConfigured && $authReady && $session && !$member}
        <p class="banner">
          {$t("You're signed in as {email}, but this email isn't linked to a membership. Access is invite-only — please ask an admin to invite you. Meanwhile you can", { email: $session.user.email })}
          <a href="/guide">{$t('read how the community works →')}</a>
        </p>
      {/if}
      {@render children()}
    </main>
  </div>
</div>
