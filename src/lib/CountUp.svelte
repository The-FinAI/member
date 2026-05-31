<script lang="ts">
  // Animated number that eases to its target whenever `value` changes.
  // Exchange-style rolling counter with tabular figures.
  let { value = 0, duration = 900, decimals = 0, prefix = '', suffix = '', class: klass = '' } =
    $props<{ value?: number; duration?: number; decimals?: number; prefix?: string; suffix?: string; class?: string }>();

  let display = $state(0);
  let raf = 0;
  let from = 0;
  let start = 0;

  const reduce = typeof window !== 'undefined' &&
    window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

  function easeOutCubic(t: number) { return 1 - Math.pow(1 - t, 3); }

  $effect(() => {
    const target = Number(value) || 0;
    if (reduce) { display = target; return; }
    cancelAnimationFrame(raf);
    from = display;
    start = performance.now();
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / duration);
      display = from + (target - from) * easeOutCubic(t);
      if (t < 1) raf = requestAnimationFrame(tick);
      else display = target;
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  const text = $derived(
    prefix + display.toLocaleString(undefined, { minimumFractionDigits: decimals, maximumFractionDigits: decimals }) + suffix
  );
</script>

<span class={'num ' + klass}>{text}</span>
