<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { session, member, capabilities, authReady, authError } from '$lib/session';
  import { loadProfile, clearProfile, claimMembership } from '$lib/profile';
  import { t } from '$lib/i18n';
  import LangSwitcher from '$lib/LangSwitcher.svelte';
  import Toaster from '$lib/shell/Toaster.svelte';
  import ConfirmDialog from '$lib/shell/ConfirmDialog.svelte';

  let { children } = $props();

  // The app IS the market (concept v49): one surface, a minimal shell.
  // /login (magic link) and /admin (President settlement door) are the only
  // other routes.
  const PUBLIC_ROUTES = ['/login'];

  let menuOpen = $state(false);
  function initials(name: string | undefined) {
    if (!name) return '·';
    const p = name.trim().split(/\s+/);
    return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toUpperCase() || '·';
  }

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
    if (!$session && !isPublic) goto('/login');
    if ($session && isPublic) goto('/market');
  });

  async function signOut() {
    await supabase.auth.signOut();
    goto('/login');
  }

  const canSettle = $derived($capabilities.has('manage_stater'));
</script>

<div class="app-shell">
  <header class="mk-head">
    <a href="/market" class="mk-brand">The Fin AI</a>
    <span class="mk-utils">
      <LangSwitcher />
      {#if $session}
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
              {#if canSettle}
                <button class="menu-item" onclick={() => { menuOpen = false; goto('/admin'); }}>{$t('Settle (President)')}</button>
              {/if}
              <button class="menu-item" onclick={signOut}>{$t('Sign out')}</button>
            </div>
          {/if}
        </div>
      {/if}
    </span>
  </header>

  <div class="main-col">
    <main class="container">
      {#if !supabaseConfigured}
        <p class="banner">
          Supabase is not configured. Copy <code>.env.example</code> to <code>.env</code> and add your
          project URL + anon key, then restart the dev server. Pages render but data calls are disabled.
        </p>
      {/if}
      {#if supabaseConfigured && $authReady && $session && !$member}
        <p class="banner">
          {$t("You're signed in as {email}, but this email isn't linked to a membership. If your email matches a member record it links automatically — otherwise ask any member to add you on the market.", { email: $session.user.email })}
        </p>
      {/if}
      {@render children()}
    </main>
  </div>
  <Toaster />
  <ConfirmDialog />
</div>

<style>
  .mk-head { display: flex; align-items: center; gap: 12px; max-width: 1120px; margin: 0 auto;
    padding: 12px 16px 0; }
  .mk-brand { font-size: 14px; font-weight: 700; color: var(--text, #37352f); text-decoration: none; letter-spacing: -.01em; }
  .mk-utils { margin-left: auto; display: inline-flex; align-items: center; gap: 10px; }
  .avatar-btn { width: 28px; height: 28px; border-radius: 50%; border: 1px solid #e9e9e7; background: #fff;
    font-size: 11px; font-weight: 600; cursor: pointer; color: #0b5e52; }
  .avatar-btn:hover { background: #f7f7f5; }
  .usermenu { position: relative; }
  .menu-backdrop { position: fixed; inset: 0; z-index: 8; }
  .menu { position: absolute; right: 0; top: 34px; z-index: 9; background: #fff; border: 1px solid #e9e9e7;
    border-radius: 10px; box-shadow: 0 8px 28px rgba(55, 53, 47, .12); padding: 6px; min-width: 200px;
    display: flex; flex-direction: column; gap: 2px; }
  .menu-head { padding: 6px 10px; }
  .mh-name { font-size: 12.5px; font-weight: 600; }
  .mh-mail { font-size: 11px; color: #98a29b; }
  .menu-sep { border-top: 1px solid #e9e9e7; margin: 3px 0; }
  .menu-item { font: inherit; font-size: 12px; text-align: left; padding: 6px 10px; border: 0; background: none;
    border-radius: 7px; cursor: pointer; }
  .menu-item:hover { background: #0b5e520d; }
  .banner { background: #fdecc8; border: 1px solid #f3dfad; border-radius: 10px; padding: 10px 14px;
    font-size: 12.5px; margin: 10px auto; max-width: 1120px; }
</style>
