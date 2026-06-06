<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { session, member, capabilities, officerUnits, authReady, authError } from '$lib/session';
  import { loadProfile, clearProfile, claimMembership } from '$lib/profile';
  import { theme, toggleTheme } from '$lib/theme';
  import { t } from '$lib/i18n';
  import LangSwitcher from '$lib/LangSwitcher.svelte';
  import LaunchBanner from '$lib/LaunchBanner.svelte';

  let { children } = $props();

  // PUBLIC_ROUTES: only valid when signed OUT — a signed-in user is bounced away
  // (e.g. /login). OPEN_ROUTES: reachable by anyone, no redirect either way
  // (e.g. /guide, so prospective members can read it before being invited).
  const PUBLIC_ROUTES = ['/login'];
  const OPEN_ROUTES = ['/guide'];

  let balance = $state<number | null>(null);
  let nominal = $state(0);
  // net value = liquid STR + nominal STR still accruing in live projects
  const netValue = $derived(balance === null ? null : balance + nominal);

  async function loadBalance(memberId: string) {
    const [{ data: bal }, { data: nom }] = await Promise.all([
      supabase.from('stater_balance').select('balance').eq('owner_member_id', memberId).maybeSingle(),
      supabase.from('stater_project_member_nominal').select('nominal').eq('member_id', memberId)
    ]);
    balance = Number((bal as { balance: number } | null)?.balance ?? 0);
    nominal = ((nom as { nominal: number }[]) ?? []).reduce((s, r) => s + (Number(r.nominal) || 0), 0);
  }

  $effect(() => { if ($member) loadBalance($member.id); else { balance = null; nominal = 0; } });

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
  // anyone who can act on at least one approval queue gets the Approvals entry
  const canApprove = $derived(
    $officerUnits.length > 0 ||
      $capabilities.has('manage_resources') ||
      $capabilities.has('manage_stater') ||
      $capabilities.has('manage_members') ||
      $capabilities.has('review_skillcard')
  );
</script>

<div class="app-shell">
  <aside class="sidebar">
    <a href="/" class="side-brand">
      <img src="/logo.png" alt="The Fin AI" class="brand-logo" />
      <span>The&nbsp;Fin&nbsp;AI <span class="muted" style="font-weight:500;">· Community</span></span>
    </a>

    {#if $session}
      <nav class="side-nav">
        <a href="/" class="side-link" class:active={$page.url.pathname === '/'}>{$t('Overview')}</a>

        <div class="side-section">{$t('Browse')}</div>
        <a href="/projects" class="side-link" class:active={isActive('/projects', $page.url.pathname)}>{$t('Projects')}</a>
        <a href="/community" class="side-link" class:active={isActive('/community', $page.url.pathname)}>{$t('Community')}</a>

        {#if $officerUnits.length > 0 || canApprove || canAdmin}
          <div class="side-section">{$t('Operate')}</div>
          {#if $officerUnits.length > 0 || canAdmin}
            <a href="/officer" class="side-link" class:active={isActive('/officer', $page.url.pathname)}>{$t('Officer console')}</a>
          {/if}
          {#if canApprove}
            <a href="/admin/forge-queue" class="side-link" class:active={isActive('/admin/forge-queue', $page.url.pathname)}>{$t('Review queue')}</a>
          {/if}
        {/if}

        <div class="side-section">{$t('More')}</div>
        <a href="/guide" class="side-link" class:active={isActive('/guide', $page.url.pathname)}>{$t('Guide')}</a>
        {#if canAdmin}
          <a href="/admin" class="side-link" class:active={isActive('/admin', $page.url.pathname)}>{$t('Admin')}</a>
        {/if}
      </nav>

      <!-- pinned footer: the member's own corner — net value (→ Wallet) + avatar (→ Profile) -->
      <div class="side-user">
        <a href="/wallet" class="su-wallet" class:active={isActive('/wallet', $page.url.pathname)} title={$t('Open your wallet')}>
          <span class="su-amt">{(netValue ?? 0).toLocaleString()}</span>
          <span class="su-unit">STR</span>
          <span class="su-tag">{$t('Net value')}</span>
        </a>
        <div class="usermenu">
          <button class="su-id" onclick={() => (menuOpen = !menuOpen)} title={$t('Account')} aria-haspopup="true" aria-expanded={menuOpen}>
            <span class="su-ava">{initials($member?.full_name)}</span>
            <span class="su-meta">
              <span class="su-name">{$member?.full_name ?? 'Account'}</span>
              <span class="su-mail">{$session.user.email}</span>
            </span>
          </button>
          {#if menuOpen}
            <div class="menu-backdrop" onclick={() => (menuOpen = false)} role="presentation"></div>
            <div class="menu menu-up">
              <button class="menu-item" onclick={() => go('/')}><span class="mi-ico">◷</span> {$t('Overview')}</button>
              <button class="menu-item" onclick={() => go($member ? `/members/${$member.id}` : '/profile')}><span class="mi-ico">⚙</span> {$t('My profile')}</button>
              <div class="menu-sep"></div>
              <button class="menu-item" onclick={signOut}><span class="mi-ico">⏻</span> {$t('Sign out')}</button>
            </div>
          {/if}
        </div>
      </div>
    {/if}
  </aside>

  <div class="main-col">
    <header class="topbar">
      <div class="container row" style="justify-content: flex-end; padding-block: .55rem; gap: 1rem;">
        <LangSwitcher />

        <button class="icon-btn" onclick={toggleTheme} title={$t('Toggle theme')} aria-label={$t('Toggle theme')}>
          {$theme === 'dark' ? '☀' : '☾'}
        </button>
      </div>
    </header>

    <main class="container">
      {#if $session && $member}<LaunchBanner />{/if}
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
