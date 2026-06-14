<script lang="ts">
  import { locale, setLocale, LOCALES, t } from '$lib/i18n';
  let open = $state(false);
  const current = $derived(LOCALES.find((l) => l.code === $locale) ?? LOCALES[0]);
  function choose(code: typeof LOCALES[number]['code']) { setLocale(code); open = false; }
</script>

<div class="lang">
  <button class="icon-btn lang-btn" onclick={() => (open = !open)} title={$t('Language')} aria-label={$t('Language')} aria-haspopup="true" aria-expanded={open}>
    {current.short}
  </button>
  {#if open}
    <div class="lang-backdrop" onclick={() => (open = false)} role="presentation"></div>
    <div class="lang-menu">
      {#each LOCALES as l}
        <button class="lang-item" class:on={l.code === $locale} onclick={() => choose(l.code)}>
          <span class="ls">{l.short}</span> {l.label}
          {#if l.code === $locale}<span class="tick">✓</span>{/if}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .lang { position: relative; display: inline-flex; }
  .lang-btn { font-size: .8rem; font-weight: 700; min-width: 34px; }
  .lang-backdrop { position: fixed; inset: 0; z-index: var(--z-backdrop); }
  .lang-menu {
    position: absolute; top: calc(100% + 8px); right: 0; z-index: var(--z-popover);
    background: var(--elevate); border: 1px solid var(--border); border-radius: var(--r-md);
    box-shadow: var(--shadow); padding: .3rem; min-width: 150px;
  }
  .lang-item {
    display: flex; align-items: center; gap: .5rem; width: 100%;
    background: transparent; border: none; border-radius: var(--r-sm);
    padding: .45rem .55rem; font-size: .85rem; color: var(--text-dim); cursor: pointer; text-align: left;
  }
  .lang-item:hover { background: var(--card); color: var(--text); }
  .lang-item.on { color: var(--accent); }
  .ls {
    flex: none; width: 22px; height: 22px; border-radius: 5px;
    display: inline-flex; align-items: center; justify-content: center;
    font-size: .72rem; font-weight: 700; background: var(--card); color: var(--muted);
  }
  .lang-item.on .ls { background: var(--accent-soft); color: var(--accent); }
  .tick { margin-left: auto; color: var(--accent); }
</style>
