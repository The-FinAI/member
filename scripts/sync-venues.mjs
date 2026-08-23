// Weekly venue sync: deadlines from ccfddl (curated), notification dates
// scraped from each conference's OFFICIAL site (ccfddl only supplies the URL).
//
//   node scripts/sync-venues.mjs            # dry run (prints planned updates)
//   SUPABASE_SERVICE_ROLE_KEY=… node …      # writes venue.deadline/.notification
//
// Runs in .github/workflows/sync-venues.yml every Monday.

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://ufptxtezwpsnvtolrfqo.supabase.co';
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const ALLCONF = 'https://ccfddl.com/conference/allconf.yml';

// venue.name (in our DB) → ccfddl title
const ALIAS = { MM: 'ACM MM' };
// official-site subpages worth probing for an "important dates" section
const SUBPATHS = ['', 'dates', 'Dates', 'calls', 'cfp', 'call-for-papers', 'important-dates', 'calls/papers'];

let dispatcher;
if (process.env.https_proxy) {
  const { ProxyAgent } = await import('undici');
  dispatcher = new ProxyAgent(process.env.https_proxy);
}
const get = async (url) => {
  const r = await fetch(url, { dispatcher, redirect: 'follow', headers: { 'user-agent': 'thefin-venue-sync/1.0' } });
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.text();
};

// ── tiny targeted parser for allconf.yml (title / confs / year / link / timeline) ──
function parseAllconf(yml) {
  const out = [];
  let cur = null, conf = null, inTimeline = false;
  for (const line of yml.split('\n')) {
    const title = line.match(/^- title: (.+)$/);
    if (title) { cur = { title: title[1].trim(), confs: [] }; out.push(cur); conf = null; continue; }
    if (!cur) continue;
    const year = line.match(/^  - year: (\d{4})/);
    if (year) { conf = { year: +year[1], link: null, deadlines: [] }; cur.confs.push(conf); inTimeline = false; continue; }
    if (!conf) continue;
    const link = line.match(/^    link: (.+)$/);
    if (link) { conf.link = link[1].trim(); continue; }
    if (/^    timeline:/.test(line)) { inTimeline = true; continue; }
    if (inTimeline) {
      const dl = line.match(/deadline: '?(\d{4}-\d{2}-\d{2})/);
      if (dl) conf.deadlines.push(dl[1]);
      else if (/^    [a-z]/.test(line)) inTimeline = false;
    }
  }
  return out;
}

// ── date extraction from official pages ──
const MONTHS = { jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12 };
function parseDates(text) {
  const found = [];
  const push = (y, m, d) => { const iso = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    if (m >= 1 && m <= 12 && d >= 1 && d <= 31) found.push(iso); };
  for (const m of text.matchAll(/(\d{4})-(\d{2})-(\d{2})/g)) push(+m[1], +m[2], +m[3]);
  for (const m of text.matchAll(/([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})/g)) {
    const mo = MONTHS[m[1].slice(0, 3).toLowerCase()]; if (mo) push(+m[3], mo, +m[2]);
  }
  for (const m of text.matchAll(/(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3,9})\.?,?\s+(\d{4})/g)) {
    const mo = MONTHS[m[2].slice(0, 3).toLowerCase()]; if (mo) push(+m[3], mo, +m[1]);
  }
  return found;
}
const strip = (html) => html.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, ' ')
  .replace(/<[^>]+>/g, ' ').replace(/&nbsp;|&amp;|&#\d+;/g, ' ').replace(/[ \t]+/g, ' ');

// Look for a date on the same line (or the next) as a notification keyword.
function findNotification(html) {
  const lines = strip(html).split(/\n|(?<=\.)\s{2,}/);
  const hits = [];
  for (let i = 0; i < lines.length; i++) {
    if (/(notification|decision|acceptance)s?\b/i.test(lines[i]) && !/camera|registration/i.test(lines[i])) {
      for (const d of [...parseDates(lines[i]), ...parseDates(lines[i + 1] ?? '')]) hits.push(d);
    }
  }
  const today = new Date().toISOString().slice(0, 10);
  const future = hits.filter((d) => d >= today).sort();
  return future[0] ?? null; // nearest upcoming notification
}

async function scrapeOfficial(link) {
  if (!link) return null;
  const base = link.replace(/\/+$/, '');
  for (const sub of SUBPATHS) {
    const url = sub ? `${base}/${sub}` : base;
    try {
      const n = findNotification(await get(url));
      if (n) return { notification: n, source: url };
    } catch { /* try next */ }
  }
  return null;
}

const today = new Date().toISOString().slice(0, 10);
const all = parseAllconf(await get(ALLCONF));
const headers = { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' };

// venue list: live from Supabase when we have a key, else the known set
let venues;
if (KEY) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/venue?select=id,name,kind`, { dispatcher, headers });
  venues = await r.json();
} else {
  venues = ['AAAI', 'ACL', 'COLM', 'EMNLP', 'ICLR', 'ICML', 'MM', 'NeurIPS', 'WWW'].map((name) => ({ id: null, name, kind: 'conference' }));
}

for (const v of venues) {
  if (v.kind === 'journal') continue;
  const entry = all.find((e) => e.title.toUpperCase() === (ALIAS[v.name] ?? v.name).toUpperCase());
  if (!entry) { console.log(`- ${v.name}: not in ccfddl, skipped`); continue; }

  // pick the year whose final deadline is nearest in the future; else the latest
  const scored = entry.confs.filter((c) => c.deadlines.length)
    .map((c) => ({ ...c, final: c.deadlines.sort().at(-1) })).sort((a, b) => a.final.localeCompare(b.final));
  const pick = scored.find((c) => c.final >= today) ?? scored.at(-1);
  if (!pick) { console.log(`- ${v.name}: no dated cycles, skipped`); continue; }

  const official = await scrapeOfficial(pick.link);
  const patch = { deadline: pick.final };
  if (official) patch.notification = official.notification;
  console.log(`- ${v.name} ${pick.year}: deadline ${pick.final}` +
    (official ? ` · notification ${official.notification} (${official.source})` : ' · notification not found on official site'));

  if (KEY && v.id) {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/venue?id=eq.${v.id}`, {
      method: 'PATCH', dispatcher, headers, body: JSON.stringify(patch)
    });
    if (!r.ok) console.error(`  ! write failed: ${r.status} ${await r.text()}`);
  }
}
console.log(KEY ? 'done (written)' : 'dry run — set SUPABASE_SERVICE_ROLE_KEY to write');
