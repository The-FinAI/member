<script lang="ts">
  // Notion/OpenReview-style person picker: type to filter, click to pick.
  // Selection is reported via onpick; the input then shows the picked name.
  type Person = { id: string; name: string; hint?: string };
  let { people, placeholder = '', onpick }: {
    people: Person[]; placeholder?: string; onpick: (id: string) => void;
  } = $props();

  let q = $state('');
  let open = $state(false);
  let picked = $state('');

  const PAL = ['#31735f', '#4c7a9b', '#8a6d3b', '#a35d48', '#5b5f97', '#6c8363', '#96694f', '#527a7a', '#7b5e7b', '#6e7f52'];
  const initials = (n: string) => { const p = n.split(' '); return ((p[0]?.[0] ?? '') + (p[1]?.[0] ?? '')).toUpperCase(); };
  const color = (n: string) => PAL[[...n].reduce((a, c) => a + c.charCodeAt(0), 0) % PAL.length];

  const filtered = $derived.by(() => {
    const s = q.trim().toLowerCase();
    const base = s ? people.filter((p) => p.name.toLowerCase().includes(s) || (p.hint ?? '').toLowerCase().includes(s)) : people;
    return base.slice(0, 8);
  });

  function pick(p: Person) {
    picked = p.name; q = p.name; open = false;
    onpick(p.id);
  }
</script>

<span class="ppick">
  <input
    {placeholder}
    bind:value={q}
    class:haspick={picked !== '' && q === picked}
    onfocus={() => (open = true)}
    oninput={() => { open = true; if (picked && q !== picked) { picked = ''; onpick(''); } }}
    onblur={() => setTimeout(() => (open = false), 150)}
  />
  {#if open && filtered.length}
    <div class="pp-list">
      {#each filtered as p (p.id)}
        <button class="pp-row" onmousedown={(e) => { e.preventDefault(); pick(p); }}>
          <span class="pp-av" style="background:{color(p.name)}22;color:{color(p.name)}">{initials(p.name)}</span>
          <span class="pp-name">{p.name}</span>
          {#if p.hint}<span class="pp-hint">{p.hint}</span>{/if}
        </button>
      {/each}
    </div>
  {/if}
</span>

<style>
  .ppick { position: relative; display: inline-flex; }
  .ppick input { width: 10rem; }
  .ppick input.haspick { color: #0b5e52; font-weight: 500; }
  .pp-list { position: absolute; top: calc(100% + 4px); left: 0; z-index: 20; background: #fff;
    border: 1px solid #e9e9e7; border-radius: 8px; box-shadow: 0 8px 28px rgba(55, 53, 47, .12);
    padding: 4px; min-width: 15rem; max-height: 16rem; overflow-y: auto;
    display: flex; flex-direction: column; gap: 1px; }
  .pp-row { display: flex; align-items: center; gap: 7px; padding: 5px 8px; border: 0; background: none; color: #37352f; width: 100%;
    border-radius: 6px; cursor: pointer; font: inherit; font-size: 12.5px; text-align: left; }
  .pp-row:hover { background: #f7f7f5; }
  .pp-av { width: 20px; height: 20px; border-radius: 50%; display: inline-flex; align-items: center;
    justify-content: center; font-size: 8.5px; font-weight: 700; flex: none; }
  .pp-name { font-weight: 500; white-space: nowrap; }
  .pp-hint { color: #9b9a97; font-size: 11px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
</style>
