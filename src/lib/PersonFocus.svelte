<script lang="ts">
  // 会议模式 · 人物聚焦:一屏一个人。分会会议的落点 —— 补容量、看承诺、当场接位。
  import { t } from '$lib/i18n';

  type Mem = { id: string; name: string; email: string; unit: string | null; hours: number | null;
    used: number; linked: boolean; skills: { name: string }[];
    resources: { name: string; typeName: string; quota: number }[] };
  type Commit = { projectId: string; projectName: string; authorship: string; amount: number; nominal: number; slotId: string };
  type Offer = { slotId: string; projectId: string; projectName: string; ask: string; ddl: string; urgent: boolean; match: boolean };

  let { m, commits, offers, nominal, settled, busy, onsetcapacity, onsethours, onseat, onproject }: {
    m: Mem; commits: Commit[]; offers: Offer[]; nominal: number; settled: number; busy: string;
    onsetcapacity: (m: Mem, hours: number) => void;
    onsethours: (c: Commit, hours: number) => void;
    onseat: (o: Offer, m: Mem, hours: number) => void;
    onproject: (projectId: string) => void;
  } = $props();

  const ROLE: Record<string, string> = { first: 'First author', corresponding: 'Co-corresponding', last: 'Last author', last_candidate: 'Last author' };
  const free = $derived(m.hours == null ? null : m.hours - m.used);
</script>

<div class="ft"><span class="fn">{m.name}</span>
  {#if !m.linked}<span class="stc gy">{$t('Card')}</span>{/if}
  {#if free != null && free < 0}<span class="stc rd">{$t('over by')} {-free}h</span>{/if}
</div>

<div class="tiles four">
  <div class="tile"><div class="tl">{$t('Chapter')}</div><div class="tv2">{m.unit ?? $t('No chapter')}</div></div>
  <div class="tile"><div class="tl">{$t('Capacity')}</div>
    <div class="tv2"><input class="num cap" type="number" min="0" placeholder="—" value={m.hours ?? ''}
        onchange={(e) => { const h = Number((e.target as HTMLInputElement).value); if (h >= 0 && h !== m.hours) onsetcapacity(m, h); }} />h/{$t('mo')}
      {#if m.hours == null}<span class="rd sm2"> · {$t('not set')}</span>{/if}</div></div>
  <div class="tile"><div class="tl">{$t('Committed')}</div>
    <div class="tv2 num" class:rd={free != null && free < 0}>{m.used}h
      {#if free != null}<span class="sm2 mut"> · {free >= 0 ? $t('free') + ' ' + free + 'h' : ''}</span>{/if}</div></div>
  <div class="tile"><div class="tl">STR</div><div class="tv2 num yl">{nominal.toLocaleString()}{#if settled}<span class="sm2 mut"> · {$t('settled')} {settled.toLocaleString()}</span>{/if}</div></div>
</div>

<div class="fcols">
  <div class="seats">
    {#each commits as c (c.slotId + c.projectId)}
      <div class="seat">
        <button class="lnk" onclick={() => onproject(c.projectId)}>{c.projectName}</button>
        <span class="rolec {c.authorship === 'first' ? 'rd' : c.authorship === 'corresponding' ? 'bl' : /last/.test(c.authorship) ? 'gn' : ''}">{$t(ROLE[c.authorship] ?? 'Author')}</span>
        <span class="give"><input class="num" type="number" min="1" value={c.amount}
          onchange={(e) => { const h = Number((e.target as HTMLInputElement).value); if (h > 0 && h !== c.amount) onsethours(c, h); }} />h</span>
        <span class="num pts">{c.nominal.toLocaleString()}</span>
      </div>
    {/each}
    {#if !commits.length}<div class="mut">{$t('on no projects yet')}</div>{/if}
  </div>
  <div class="zeros">
    {#if offers.length}
      <div class="zt">{$t('Seats this person could take')}</div>
      <div class="zchips">
        {#each offers as o (o.slotId)}
          <button class="offer" class:match={o.match} disabled={busy === 'seat' + o.slotId}
            onclick={() => onseat(o, m, Math.max(1, Math.min(free ?? 5, 5)))}>
            <span class="on">{o.projectName}</span>
            <span class="oa mut">{o.ask}</span>
            {#if o.ddl}<span class="num" class:rd={o.urgent}>{o.ddl}</span>{/if}
          </button>
        {/each}
      </div>
      <div class="mut">{$t('click to seat them at 5h/mo — adjust on the left')}</div>
    {/if}
  </div>
</div>

<style>
  .num { font-family: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace; font-variant-numeric: tabular-nums; }
  .mut { color: #9b9a97; }
  .rd { color: #93382a; } .yl { color: #6f5615; }
  .ft { display: flex; align-items: baseline; gap: 14px; margin-bottom: 22px; }
  .fn { font-size: 44px; font-weight: 600; letter-spacing: -.015em; }
  .stc { font-size: 13px; border-radius: 4px; padding: 2px 9px; white-space: nowrap; }
  .stc.gy { background: #f1f0ef; color: #57564f; } .stc.rd { background: #ffe2dd; color: #93382a; }
  .tiles { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; margin-bottom: 26px; }
  .tile { border: 1px solid #e9e9e7; border-radius: 8px; padding: 14px 18px; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .tl { font-size: 12.5px; font-weight: 600; color: #9b9a97; text-transform: uppercase; letter-spacing: .04em; }
  .tv2 { font-size: 22px; font-weight: 600; }
  .sm2 { font-size: 15px; font-weight: 500; }
  .cap { font: inherit; font-size: 22px; font-weight: 600; width: 3.6rem; border: 1px solid transparent; border-radius: 4px; padding: 0 2px; background: none; color: inherit; }
  .cap:hover, .cap:focus { border-color: #e9e9e7; background: #fff; outline: none; }
  .fcols { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 48px; }
  .seats { display: flex; flex-direction: column; }
  .seat { display: grid; grid-template-columns: 1fr 150px 100px 80px; gap: 12px; align-items: center; padding: 12px 8px; border-bottom: 1px solid #f1f1ef; }
  .lnk { font: inherit; font-size: 19px; font-weight: 500; text-align: left; background: none; border: 0; color: #37352f; cursor: pointer;
    padding: 2px 6px; margin-left: -6px; border-radius: 6px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .lnk:hover { background: #f7f7f5; }
  .rolec { font-size: 13px; color: #6b6a66; justify-self: start; border-radius: 4px; padding: 2px 8px; }
  .rolec.rd { background: #ffe2dd; color: #93382a; } .rolec.bl { background: #d3e5ef; color: #2b5a75; } .rolec.gn { background: #dbeddb; color: #1c513f; }
  .give { justify-self: end; font-size: 17px; }
  .give input { font: inherit; font-size: 17px; width: 4rem; text-align: right; border: 1px solid transparent; border-radius: 4px; padding: 2px 4px; background: none; }
  .give input:hover, .give input:focus { border-color: #e9e9e7; background: #fff; outline: none; }
  .pts { justify-self: end; font-size: 14px; color: #6f5615; background: #fdecc8; border-radius: 4px; padding: 2px 8px; }
  .zeros { display: flex; flex-direction: column; gap: 10px; padding-top: 12px; }
  .zt { font-size: 13px; color: #6b6a66; font-weight: 600; }
  .zchips { display: flex; flex-wrap: wrap; gap: 8px; }
  .offer { font: inherit; display: inline-flex; align-items: center; gap: 8px; font-size: 15px; cursor: pointer;
    border: 1px dashed #e9e9e7; background: #fff; border-radius: 6px; padding: 6px 12px; color: #6b6a66; max-width: 100%; }
  .offer:hover { border-style: solid; border-color: #c9c8c4; background: #f7f7f5; }
  .offer:disabled { opacity: .5; }
  .offer.match { border-color: #dbeddb; background: #f4faf4; }
  .offer .on { color: #37352f; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 16rem; }
  .offer .oa { font-size: 13px; }
  @media (max-width: 1100px) { .tiles { grid-template-columns: repeat(2, minmax(0, 1fr)); } .fcols { grid-template-columns: 1fr; } }
</style>
