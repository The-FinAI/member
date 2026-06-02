<script lang="ts">
  // Minimal monochrome line icons for the sidebar rail. Stroke = currentColor so
  // they inherit the nav link's active/idle colour. Kept inline (no icon dep) to
  // stay in the trading-terminal aesthetic.
  let { name = '', size = 18 }: { name: string; size?: number } = $props();
</script>

<svg
  class="nav-ico"
  width={size} height={size} viewBox="0 0 24 24"
  fill="none" stroke="currentColor" stroke-width="1.7"
  stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"
>
  {#if name === 'home'}
    <path d="M3 10.5 12 3l9 7.5" /><path d="M5 9.5V21h14V9.5" /><path d="M10 21v-6h4v6" />
  {:else if name === 'projects'}
    <rect x="3.5" y="3.5" width="7" height="7" rx="1.2" /><rect x="13.5" y="3.5" width="7" height="7" rx="1.2" />
    <rect x="3.5" y="13.5" width="7" height="7" rx="1.2" /><rect x="13.5" y="13.5" width="7" height="7" rx="1.2" />
  {:else if name === 'market'}
    <path d="M4 20h16" /><path d="M6 20v-6" /><path d="M11 20V8" /><path d="M16 20v-9" /><path d="M21 20V5" />
  {:else if name === 'people'}
    <circle cx="9" cy="8" r="3.2" /><path d="M3.5 20a5.5 5.5 0 0 1 11 0" />
    <path d="M16 5.2a3.2 3.2 0 0 1 0 6" /><path d="M17 15.3A5.5 5.5 0 0 1 20.5 20" />
  {:else if name === 'guild'}
    <circle cx="12" cy="9" r="5.2" /><path d="M8.5 13.5 7 21l5-2.6L17 21l-1.5-7.5" />
  {:else if name === 'units'}
    <path d="M3 21h18" /><path d="M5 21V6l7-3 7 3v15" /><path d="M9.5 9h5M9.5 12.5h5M9.5 16h5" />
  {:else if name === 'guide'}
    <path d="M5 4.5A1.5 1.5 0 0 1 6.5 3H19v15H6.5A1.5 1.5 0 0 0 5 19.5z" /><path d="M5 19.5A1.5 1.5 0 0 1 6.5 21H19" />
  {:else if name === 'chapter'}
    <path d="M6 21V4" /><path d="M6 4h11l-2.2 3.5L17 11H6" />
  {:else if name === 'admin'}
    <path d="M5 7h14M5 12h14M5 17h14" /><circle cx="9" cy="7" r="1.6" fill="currentColor" stroke="none" />
    <circle cx="15" cy="12" r="1.6" fill="currentColor" stroke="none" /><circle cx="8" cy="17" r="1.6" fill="currentColor" stroke="none" />
  {:else if name === 'wallet'}
    <rect x="3" y="6" width="18" height="13" rx="2.2" /><path d="M3 9.5h18" /><circle cx="16.5" cy="13.5" r="1.1" fill="currentColor" stroke="none" />
  {/if}
</svg>

<style>
  .nav-ico { flex: none; display: block; }
</style>
