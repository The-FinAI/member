<script lang="ts">
  // 会议模式 · 人物聚焦:一屏一个人。分会会议的落点 —— 补容量、看承诺、当场接位。
  import { t } from '$lib/i18n';

  type Mem = { id: string; name: string; email: string; unit: string | null; hours: number | null;
    used: number; linked: boolean; skills: { id: string; name: string; level: string }[];
    resources: { id: string; name: string; typeName: string; quota: number }[] };
  type Give = { slotId: string; rtype: string; unit: string; amount: number };
  type Commit = { projectId: string; projectName: string; authorship: string; amount: number; nominal: number; slotId: string; gives: Give[] };
  type Offer = { slotId: string; projectId: string; projectName: string; ask: string; ddl: string; urgent: boolean; match: boolean };

  let { m, commits, offers, nominal, settled, busy, skills, resourceTypes, gpuModels,
        onsetcapacity, onsethours, onseat, onproject, onsetskill, onaddresource, onsetquota, onsetgive }: {
    m: Mem; commits: Commit[]; offers: Offer[]; nominal: number; settled: number; busy: string;
    skills: { id: string; name: string }[]; resourceTypes: { id: string; name: string }[]; gpuModels: { id: string; name: string }[];
    onsetcapacity: (m: Mem, hours: number) => void;
    onsethours: (c: Commit, hours: number) => void;
    onseat: (o: Offer, m: Mem, hours: number) => void;
    onproject: (projectId: string) => void;
    onsetskill: (memberId: string, skillId: string, level: string | null) => void;
    onaddresource: (memberId: string, typeId: string, qty: number, gpuModelId: string | null) => void;
    onsetquota: (resourceId: string, qty: number) => void;
    onsetgive: (memberId: string, slotId: string, qty: number) => void;
  } = $props();

  // plain object on purpose: a reactive draft would re-render and close the adder
  const d = { skill: '', level: 'independent', res: '', qty: '', gpu: '' };

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

<div class="caps">
  <span class="cl">{$t('Skills & resources')}</span>
  {#each m.skills as sk (sk.id)}
    <span class="chip"><span class="cn" title={sk.name}>{sk.name}</span>
      <select class="lvlsel" value={sk.level}
        onchange={(e) => { const lv = (e.target as HTMLSelectElement).value; sk.level = lv; onsetskill(m.id, sk.id, lv); }}>
        <option value="learning">{$t('Lrn')}</option>
        <option value="independent">{$t('Ind')}</option>
        <option value="lead">{$t('Lead')}</option>
      </select>
      <button class="chipx" title={$t('Remove')} onclick={() => onsetskill(m.id, sk.id, null)}>×</button></span>
  {/each}
  {#each m.resources as r (r.id)}
    <span class="chip rs">{r.typeName}
      <input class="q num" type="number" min="0" value={r.quota}
        onchange={(e) => { const q = Number((e.target as HTMLInputElement).value); if (q >= 0) { r.quota = q; onsetquota(r.id, q); } }} /></span>
  {/each}
  {#if !m.skills.length && !m.resources.length}<span class="chip mutc">{$t('no skills set')}</span>{/if}
  <details class="add"><summary>+ {$t('Add skill / resource')}</summary>
    <div class="addbox">
      <div class="addrow">
        <select bind:value={d.skill}><option value="">{$t('Skill')}…</option>
          {#each skills as sk}<option value={sk.id}>{sk.name}</option>{/each}</select>
        <select bind:value={d.level}>
          <option value="independent">{$t('Independent')}</option>
          <option value="learning">{$t('Learning')}</option>
          <option value="lead">{$t('Can mentor')}</option></select>
        <button class="bt" disabled={busy === m.id} onclick={() => { if (d.skill) onsetskill(m.id, d.skill, d.level || 'independent'); }}>{$t('Add')}</button>
      </div>
      <div class="addrow">
        <select bind:value={d.res}><option value="">{$t('Resource')}…</option>
          {#each resourceTypes.filter((x) => x.name !== 'Labor') as ty}<option value={ty.id}>{ty.name}</option>{/each}</select>
        <input class="num" type="number" min="1" placeholder={$t('qty')} bind:value={d.qty} style="width:4.6rem" />
        <select bind:value={d.gpu} style="max-width:7.5rem" title="GPU model">
          {#each gpuModels as g}<option value={g.id}>{g.name}</option>{/each}</select>
        <button class="bt" disabled={busy === 'res' + m.id}
          onclick={() => { const q = Number(d.qty); if (d.res && q > 0) onaddresource(m.id, d.res, q, d.gpu || null); }}>{$t('Add')}</button>
      </div>
    </div>
  </details>
</div>

<div class="fcols">
  <div class="seats">
    {#each commits as c (c.slotId + c.projectId)}
      <div class="seat">
        <button class="lnk" onclick={() => onproject(c.projectId)}>{c.projectName}</button>
        <span class="rolec {c.authorship === 'first' ? 'rd' : c.authorship === 'corresponding' ? 'bl' : /last/.test(c.authorship) ? 'gn' : ''}">{$t(ROLE[c.authorship] ?? 'Author')}</span>
        <span class="give">
          {#if c.amount || !c.gives.length}<input class="num" type="number" min="1" value={c.amount}
            onchange={(e) => { const h = Number((e.target as HTMLInputElement).value); if (h > 0 && h !== c.amount) onsethours(c, h); }} />h{/if}
          {#each c.gives as g (g.slotId)}<span class="gv" title={g.unit}>{g.rtype}<input class="num" type="number" min="1" value={g.amount}
            onchange={(e) => { const q = Number((e.target as HTMLInputElement).value); if (q > 0 && q !== g.amount) onsetgive(m.id, g.slotId, q); }} /></span>{/each}
        </span>
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
  .caps { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 0 0 22px; }
  .cl { font-size: 12.5px; font-weight: 600; color: #9b9a97; text-transform: uppercase; letter-spacing: .04em; margin-right: 4px; }
  .chip { display: inline-flex; align-items: center; gap: 4px; background: #f1f0ef; color: #57564f;
    border-radius: 4px; font-size: 14px; padding: 3px 8px; max-width: 100%; }
  .chip.rs { background: #e8deee; color: #5a4a72; }
  .chip.mutc { color: #9b9a97; background: transparent; border: 1px dashed #e9e9e7; }
  .chip .cn { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 12rem; }
  .lvlsel, .chipx { font: inherit; font-size: 12px; border: 0; background: none; color: inherit; cursor: pointer; padding: 0; }
  .chipx { font-weight: 600; opacity: .5; }
  .chipx:hover { opacity: 1; color: #93382a; }
  .chip .q { font: inherit; font-size: 13px; width: 3.4rem; text-align: right; border: 1px solid transparent;
    border-radius: 4px; background: none; color: inherit; padding: 0 2px; }
  .chip .q:hover, .chip .q:focus { border-color: #c9c8c4; background: #fff; outline: none; }
  .add > summary { list-style: none; cursor: pointer; font-size: 13px; color: #6b6a66; border-radius: 6px; padding: 3px 8px; }
  .add > summary::-webkit-details-marker { display: none; }
  .add > summary:hover { background: #f7f7f5; color: #37352f; }
  .addbox { display: flex; flex-direction: column; gap: 8px; margin-top: 8px; }
  .addrow { display: flex; align-items: center; gap: 8px; }
  .addrow select, .addrow input { font: inherit; font-size: 14px; border: 1px solid #e9e9e7; border-radius: 6px; padding: 5px 8px; background: #fff; color: #37352f; }
  .bt { font: inherit; font-size: 13px; font-weight: 500; color: #fff; background: #37352f; border: 0; border-radius: 6px; padding: 5px 12px; cursor: pointer; }
  .bt:disabled { opacity: .5; }
  .fcols { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 48px; }
  .seats { display: flex; flex-direction: column; }
  .seat { display: grid; grid-template-columns: 1fr 150px minmax(100px, auto) 80px; gap: 12px; align-items: center; padding: 12px 8px; border-bottom: 1px solid #f1f1ef; }
  .lnk { font: inherit; font-size: 19px; font-weight: 500; text-align: left; background: none; border: 0; color: #37352f; cursor: pointer;
    padding: 2px 6px; margin-left: -6px; border-radius: 6px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .lnk:hover { background: #f7f7f5; }
  .rolec { font-size: 13px; color: #6b6a66; justify-self: start; border-radius: 4px; padding: 2px 8px; }
  .rolec.rd { background: #ffe2dd; color: #93382a; } .rolec.bl { background: #d3e5ef; color: #2b5a75; } .rolec.gn { background: #dbeddb; color: #1c513f; }
  .give { justify-self: end; font-size: 17px; }
  .give input { font: inherit; font-size: 17px; width: 4rem; text-align: right; border: 1px solid transparent; border-radius: 4px; padding: 2px 4px; background: none; }
  .give input:hover, .give input:focus { border-color: #e9e9e7; background: #fff; outline: none; }
  .gv { display: inline-flex; align-items: center; gap: 2px; font-size: 13px; background: #e8deee; color: #5a4a72; border-radius: 4px; padding: 1px 2px 1px 8px; margin-left: 6px; }
  .gv input { width: 3.2rem !important; font-size: 14px !important; }
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
