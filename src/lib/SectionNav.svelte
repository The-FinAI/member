<script lang="ts">
  // Sticky in-page section nav for busy entity detail pages. Pass the sections
  // that are actually rendered (id must match an element on the page). A scroll-
  // spy highlights whichever section is currently in view; clicking smooth-
  // scrolls to it. Re-observes when the section list changes (cards that appear
  // after data loads).
  import { t } from '$lib/i18n';

  let { sections = [], title = 'On this page' }:
    { sections: { id: string; label: string }[]; title?: string } = $props();

  let active = $state('');

  $effect(() => {
    if (typeof document === 'undefined' || !sections.length) return;
    const els = sections
      .map((s) => document.getElementById(s.id))
      .filter((el): el is HTMLElement => !!el);
    if (!els.length) return;
    if (!active) active = els[0].id;

    const obs = new IntersectionObserver(
      (entries) => {
        const vis = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        if (vis[0]) active = vis[0].target.id;
      },
      { rootMargin: '-72px 0px -65% 0px', threshold: 0 }
    );
    els.forEach((el) => obs.observe(el));
    return () => obs.disconnect();
  });

  function go(e: MouseEvent, id: string) {
    e.preventDefault();
    const el = document.getElementById(id);
    if (!el) return;
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    active = id;
    history.replaceState(null, '', `#${id}`);
  }
</script>

{#if sections.length > 1}
  <nav class="detail-nav">
    <span class="dn-title">{$t(title)}</span>
    {#each sections as s (s.id)}
      <a href={`#${s.id}`} class:active={active === s.id} onclick={(e) => go(e, s.id)}>{$t(s.label)}</a>
    {/each}
  </nav>
{/if}
