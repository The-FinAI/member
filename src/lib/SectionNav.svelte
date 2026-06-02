<script lang="ts">
  // Tabbed in-page nav for busy entity detail pages. Each `section` id must
  // match an element rendered on the page (inside `.detail-body`). This renders
  // a horizontal tab strip; selecting a tab shows ONLY that section and hides
  // the rest, so a long detail page reads as a set of tabs instead of one
  // endless scroll. The component owns the show/hide by toggling element
  // display, so host pages only need to give each section the matching id.
  import { t } from '$lib/i18n';

  let { sections = [], title = 'On this page' }:
    { sections: { id: string; label: string }[]; title?: string } = $props();

  let active = $state('');

  $effect(() => {
    if (typeof document === 'undefined' || !sections.length) return;
    const ids = sections.map((s) => s.id);
    // keep `active` valid as conditional sections appear/disappear
    const cur = active && ids.includes(active) ? active : ids[0];
    if (cur !== active) active = cur;
    // show only the active section, hide the others
    for (const s of sections) {
      const el = document.getElementById(s.id);
      if (el) el.style.display = s.id === cur ? '' : 'none';
    }
  });

  function go(e: MouseEvent, id: string) {
    e.preventDefault();
    active = id;
    history.replaceState(null, '', `#${id}`);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
</script>

{#if sections.length > 1}
  <nav class="detail-nav" role="tablist" aria-label={$t(title)}>
    {#each sections as s (s.id)}
      <a
        href={`#${s.id}`}
        role="tab"
        aria-selected={active === s.id}
        class:active={active === s.id}
        onclick={(e) => go(e, s.id)}
      >{$t(s.label)}</a>
    {/each}
  </nav>
{/if}
