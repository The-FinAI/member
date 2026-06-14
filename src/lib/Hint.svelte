<script lang="ts">
  // Inline "?" info dot. Hover/focus shows a small tooltip; if `term` is given,
  // it links to the matching glossary anchor on /guide.
  let { text, term = '' }: { text: string; term?: string } = $props();
  let open = $state(false);
</script>

<span
  class="hint"
  onmouseenter={() => (open = true)}
  onmouseleave={() => (open = false)}
  role="note"
>
  <button
    type="button"
    class="dot"
    aria-label="What is this?"
    onfocus={() => (open = true)}
    onblur={() => (open = false)}
    onclick={(e) => { e.preventDefault(); open = !open; }}
  >?</button>
  {#if open}
    <span class="bubble">
      {text}
      {#if term}
        <a href={`/guide#term-${term}`} class="more">Learn more →</a>
      {/if}
    </span>
  {/if}
</span>

<style>
  .hint { position: relative; display: inline-flex; vertical-align: middle; margin-left: .3rem; }
  .dot {
    width: 15px; height: 15px; border-radius: 50%;
    border: 1px solid var(--border); background: transparent;
    color: var(--muted); font-size: .68rem; line-height: 1; font-weight: 700;
    display: inline-flex; align-items: center; justify-content: center;
    cursor: help; padding: 0; transition: color .12s, border-color .12s;
  }
  .dot:hover, .dot:focus-visible { color: var(--accent); border-color: var(--accent); outline: none; }
  .bubble {
    position: absolute; bottom: calc(100% + 7px); left: 50%; transform: translateX(-50%);
    width: max-content; max-width: 248px; z-index: var(--z-tooltip);
    background: var(--elevate); color: var(--text-dim);
    border: 1px solid var(--border); border-radius: var(--r-sm);
    padding: .55rem .65rem; font-size: .76rem; font-weight: 400; line-height: 1.45;
    box-shadow: var(--shadow); text-align: left; white-space: normal;
  }
  .bubble::after {
    content: ''; position: absolute; top: 100%; left: 50%; transform: translateX(-50%);
    border: 5px solid transparent; border-top-color: var(--border);
  }
  .more { display: block; margin-top: .35rem; color: var(--accent); font-weight: 600; text-decoration: none; }
  .more:hover { text-decoration: underline; }
</style>
