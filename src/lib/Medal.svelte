<script lang="ts">
  import { t } from '$lib/i18n';

  // A certified role-card shown as a medal: skill name + guild level.
  let { name = '', level, size = 'md' }: { name?: string; level: string; size?: 'sm' | 'md' } = $props();

  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman',
    craftsman: 'Craftsman', master: 'Master'
  };
  // ascending rarity — master is the brightest
  const ICON: Record<string, string> = {
    apprentice: '🔰', journeyman: '⚒️', craftsman: '🛠️', master: '👑'
  };
</script>

<span class="medal {level} {size}" title={$t(LEVEL_LABEL[level] ?? level)}>
  <span class="ic">{ICON[level] ?? '⚒️'}</span>
  <span class="nm">{name}</span>
  <span class="lv">{$t(LEVEL_LABEL[level] ?? level)}</span>
</span>

<style>
  .medal {
    display: inline-flex; align-items: center; gap: .35rem;
    padding: .2rem .5rem; border-radius: 999px;
    border: 1px solid var(--border); background: var(--card-2);
    font-size: .76rem; line-height: 1; white-space: nowrap;
  }
  .medal.sm { font-size: .68rem; padding: .15rem .4rem; gap: .25rem; }
  .medal .ic { font-size: .9em; }
  .medal .nm { font-weight: 600; }
  .medal .lv { opacity: .7; font-size: .9em; }
  /* level tints */
  .medal.apprentice { border-color: color-mix(in srgb, var(--border) 70%, #8a8a8a); }
  .medal.journeyman { border-color: color-mix(in srgb, var(--accent) 35%, var(--border)); }
  .medal.craftsman  { border-color: color-mix(in srgb, var(--accent) 60%, var(--border));
                      background: color-mix(in srgb, var(--accent-soft) 60%, var(--card-2)); }
  .medal.master     { border-color: var(--accent);
                      background: var(--accent-soft);
                      box-shadow: 0 0 0 1px color-mix(in srgb, var(--accent) 40%, transparent) inset; }
</style>
