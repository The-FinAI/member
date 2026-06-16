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
  import NotificationInbox from '$lib/shell/NotificationInbox.svelte';
  import Toaster from '$lib/shell/Toaster.svelte';
  import ConfirmDialog from '$lib/shell/ConfirmDialog.svelte';
  import LaunchBanner from '$lib/LaunchBanner.svelte';
  import Icon from '$lib/Icon.svelte';
  import Hint from '$lib/Hint.svelte';

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
    if ($session && isPublic) goto('/projects');
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
  <!-- THE MASTHEAD — the app is typeset like the record it keeps.
       Row 1: dateline (date · your hats · utilities). Row 2: the title.
       Row 3: sections, ruled thick-over-thin, sticky. -->
  <header class="masthead">
    <div class="mast-inner">
      <div class="dateline">
        <span class="dl-date">{new Date().toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</span>
        {#if $member}
          <span class="dl-hats">
            {$member.full_name}{#if $officerUnits.length} · {$officerUnits.map((u) => u.name).join(' · ')}{/if}
          </span>
        {/if}
        <span class="dl-utils">
          <LangSwitcher />
          {#if $session && $member}<NotificationInbox />{/if}
          <button class="icon-btn" onclick={toggleTheme} title={$t('Toggle theme')} aria-label={$t('Toggle theme')}>
            <Icon name={$theme === 'dark' ? 'sun' : 'moon'} size={15} />
          </button>
        </span>
      </div>

      <div class="mast-title">
        <img src="/logo.png" alt="" class="brand-logo" />
        <a href="/projects" class="mast-brand">The Fin AI <span class="mb-sub">{$t('Community')} · {$t('The Living Record')}</span></a>
        {#if $session}
          <span class="mast-right">
            <a href="/wallet" class="mast-wallet" title={$t('STR is your contribution credit — it accrues from work and settles when a project finishes. Click for your wallet; the Guide explains how it works.')}>
              <Icon name="str" size={15} /> {(netValue ?? 0).toLocaleString()} <span class="mw-unit">STR</span>
            </a>
            <Hint term="str" text={$t('STR is your contribution credit: it accrues as you work and becomes spendable when a project settles. It is not money.')} />
            <div class="usermenu">
              <button class="avatar-btn" onclick={() => (menuOpen = !menuOpen)} title={$t('Account')} aria-haspopup="true" aria-expanded={menuOpen}>
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
                  <button class="menu-item" onclick={() => go('/my')}><span class="mi-ico"><Icon name="check" /></span> {$t('My tasks')}</button>
                  <button class="menu-item" onclick={() => go($member ? `/members/${$member.id}` : '/profile')}><span class="mi-ico"><Icon name="user" /></span> {$t('My profile')}</button>
                  <button class="menu-item" onclick={() => go('/wallet')}><span class="mi-ico"><Icon name="str" /></span> {$t('Wallet')}</button>
                  <div class="menu-sep"></div>
                  <button class="menu-item" onclick={signOut}><span class="mi-ico"><Icon name="power" /></span> {$t('Sign out')}</button>
                </div>
              {/if}
            </div>
          </span>
        {/if}
      </div>
    </div>

    {#if $session}
      <nav class="sections">
        <div class="sections-inner">
          <a href="/projects" class="sec-link" class:active={$page.url.pathname === '/' || isActive('/projects', $page.url.pathname)}>{$t('Projects')}</a>
          <a href="/people" class="sec-link" class:active={isActive('/people', $page.url.pathname)}>{$t('People')}</a>
          <span class="sec-spacer"></span>
          <a href="/community" class="sec-link" class:active={isActive('/community', $page.url.pathname)}>{$t('Directory')}</a>
          <a href="/guide" class="sec-link" class:active={isActive('/guide', $page.url.pathname)}>{$t('Guide')}</a>
          {#if canAdmin || canApprove}
            <a href="/admin" class="sec-link" class:active={isActive('/admin', $page.url.pathname)}>{$t('Admin')}</a>
          {/if}
        </div>
      </nav>
    {/if}
  </header>

  <div class="main-col">
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
  <Toaster />
  <ConfirmDialog />
</div>
