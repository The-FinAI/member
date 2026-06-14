<script lang="ts">
  // The one icon system. Monoline, currentColor, square-cut to match the
  // broadsheet — replaces the emoji/unicode mishmash. Usage: <Icon name="bell" />.
  // size in px (default 16, inherits text color). Add new glyphs here only.
  let { name, size = 16, strokeWidth = 1.6, title }:
    { name: string; size?: number; strokeWidth?: number; title?: string } = $props();

  // each entry is the inner markup of a 24×24 viewBox, stroked with currentColor
  const P: Record<string, string> = {
    close:    '<path d="M6 6l12 12M18 6L6 18"/>',
    check:    '<path d="M5 13l4 4L19 7"/>',
    edit:     '<path d="M4 20h4L19 9l-4-4L4 16v4z"/><path d="M14 6l4 4"/>',
    bell:     '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2.5h-15L6 16z"/><path d="M10 19a2 2 0 0 0 4 0"/>',
    sun:      '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M19 5l-1.5 1.5M6.5 17.5L5 19"/>',
    moon:     '<path d="M20 14a8 8 0 1 1-9.9-9.9A7 7 0 0 0 20 14z"/>',
    str:      '<path d="M12 3l3 4.5L12 12 9 7.5 12 3z"/><path d="M12 12l3 4.5L12 21l-3-4.5L12 12z"/>',
    swap:     '<path d="M4 8h13l-3-3M20 16H7l3 3"/>',
    clock:    '<circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/>',
    tasks:    '<path d="M9 6h11M9 12h11M9 18h11"/><path d="M4 6l1.2 1.2L7 5M4 17.8l1.2 1.2L7 16.8"/>',
    scale:    '<path d="M12 4v16M6 20h12M5 8h14M5 8l-2.5 5a3 3 0 0 0 5 0L5 8zM19 8l-2.5 5a3 3 0 0 0 5 0L19 8z"/>',
    power:    '<path d="M12 4v8"/><path d="M7.5 7.5a7 7 0 1 0 9 0"/>',
    arrow:    '<path d="M5 12h13M13 6l6 6-6 6"/>',
    chevron:  '<path d="M9 6l6 6-6 6"/>',
    plus:     '<path d="M12 5v14M5 12h14"/>',
    seal:     '<path d="M12 3l2.4 1.7 2.9-.3 1 2.8 2.4 1.7-.9 2.8.9 2.8-2.4 1.7-1 2.8-2.9-.3L12 21l-2.4-1.7-2.9.3-1-2.8L3.3 15l.9-2.8-.9-2.8 2.4-1.7 1-2.8 2.9.3L12 3z"/>',
    user:     '<circle cx="12" cy="8" r="3.5"/><path d="M5 20a7 7 0 0 1 14 0"/>',
    search:   '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
    link:     '<path d="M9 15l6-6"/><path d="M8 12l-2 2a3.5 3.5 0 0 0 5 5l2-2M16 12l2-2a3.5 3.5 0 0 0-5-5l-2 2"/>',
    calendar: '<rect x="4" y="5" width="16" height="15" rx="1"/><path d="M4 9h16M8 3v4M16 3v4"/>',
    info:     '<circle cx="12" cy="12" r="8"/><path d="M12 11v5M12 8h.01"/>',
    note:     '<path d="M5 4h14v16l-4-3H5z"/><path d="M9 9h6M9 13h4"/>',
    warn:     '<path d="M12 4l9 16H3L12 4z"/><path d="M12 10v4M12 17h.01"/>',
    play:     '<path d="M8 5l11 7-11 7V5z"/>',
    pause:    '<path d="M9 5v14M15 5v14"/>',
    undo:     '<path d="M4 10h9a5 5 0 0 1 0 10h-3"/><path d="M8 6l-4 4 4 4"/>',
    minus:    '<path d="M5 12h14"/>',
    trash:    '<path d="M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13"/>',
    award:    '<circle cx="12" cy="9" r="5"/><path d="M9 13l-1.5 8L12 18l4.5 3L15 13"/>',
    megaphone:'<path d="M4 10v4h4l8 5V5l-8 5H4z"/><path d="M18 9a4 4 0 0 1 0 6"/>',
    // file-type marks for project links
    doc:      '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 13h6M9 17h6"/>',
    code:     '<path d="M9 8l-4 4 4 4M15 8l4 4-4 4"/>',
    data:     '<ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v12c0 1.7 3.1 3 7 3s7-1.3 7-3V6M5 12c0 1.7 3.1 3 7 3s7-1.3 7-3"/>',
    sheet:    '<rect x="4" y="4" width="16" height="16" rx="1"/><path d="M4 10h16M4 15h16M10 4v16"/>',
    folder:   '<path d="M4 7h6l2 2h8v10H4z"/>',
    film:     '<rect x="4" y="5" width="16" height="14" rx="1"/><path d="M4 9h16M4 15h16M8 5v14M16 5v14"/>'
  };
  const inner = $derived(P[name] ?? P.info);
</script>

<svg class="ic" width={size} height={size} viewBox="0 0 24 24" fill="none"
  stroke="currentColor" stroke-width={strokeWidth} stroke-linecap="round" stroke-linejoin="round"
  aria-hidden={title ? undefined : 'true'} role={title ? 'img' : undefined} focusable="false">
  {#if title}<title>{title}</title>{/if}
  {@html inner}
</svg>

<style>
  .ic { display: inline-block; vertical-align: -.15em; flex: none; }
</style>
