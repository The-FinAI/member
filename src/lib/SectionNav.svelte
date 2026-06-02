<script lang="ts">
  // Tabbed in-page nav for busy entity detail pages. Each `section` id must
  // match an element rendered alongside this nav (inside the sibling
  // `.detail-body`). This renders a horizontal tab strip; selecting a tab shows
  // ONLY that section and hides the rest, so a long detail page reads as a set
  // of tabs instead of one endless scroll. The component owns the show/hide by
  // toggling element display, so host pages only need to give each section the
  // matching id.
  //
  // IMPORTANT: lookups are SCOPED to this nav's own `.detail` container (not the
  // whole document) so the same detail component can be rendered twice at once —
  // e.g. on its route page AND inside a quick-view drawer — without the two
  // instances colliding on duplicate element ids.
  import { t } from '$lib/i18n';

  let { sections = [], title = 'On this page' }:
    { sections: { id: string; label: string }[]; title?: string } = $props();

  let active = $state('');
  let navEl = $state<HTMLElement | null>(null);

  // the section elements live in the `.detail-body` that is a sibling of this
  // nav inside a shared `.detail` wrapper — query within that subtree only
  function scopeOf(): ParentNode | null {
    return navEl?.closest('.detail') ?? null;
  }
  function findSection(scope: ParentNode, id: string): HTMLElement | null {
    try { return scope.querySelector<HTMLElement>(`#${CSS.escape(id)}`); }
    catch { return null; }
  }

  $effect(() => {
    if (typeof document === 'undefined' || !sections.length) return;
    const scope = scopeOf();
    if (!scope) return;
    const ids = sections.map((s) => s.id);
    // keep `active` valid as conditional sections appear/disappear
    const cur = active && ids.includes(active) ? active : ids[0];
    if (cur !== active) active = cur;
    // show only the active section, hide the others
    for (const s of sections) {
      const el = findSection(scope, s.id);
      if (el) el.style.display = s.id === cur ? '' : 'none';
    }
  });

  function go(e: MouseEvent, id: string) {
    e.preventDefault();
    active = id;
    // bring the top of this nav's section group back into view, scrolling the
    // nearest scroll container (works inside both the page and a drawer)
    navEl?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }
</script>

{#if sections.length > 1}
  <div class="detail-nav" role="tablist" aria-label={$t(title)} bind:this={navEl}>
    {#each sections as s (s.id)}
      <a
        href={`#${s.id}`}
        role="tab"
        aria-selected={active === s.id}
        class:active={active === s.id}
        onclick={(e) => go(e, s.id)}
      >{$t(s.label)}</a>
    {/each}
  </div>
{/if}
