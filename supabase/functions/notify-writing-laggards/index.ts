// Supabase Edge Function: notify-writing-laggards
//
// Emails this month's first-author-writing laggards a reminder. An admin
// triggers it manually from /admin/writing.
//
// Security model: the laggard list is fetched with the *caller's* JWT via the
// `writing_laggards()` SECURITY DEFINER function, which is itself gated by the
// `manage_stater` capability. A caller without that capability gets an empty
// list (or error) and no emails go out — so this can't be used to spam.
//
// Optionally accepts `leader_ids: string[]` to remind a subset; with none it
// reminds every current-month laggard.
//
// Required secret:  RESEND_API_KEY
// Optional secrets: INVITE_FROM, SITE_URL
// Auto-provided: SUPABASE_URL, SUPABASE_ANON_KEY

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

const SITE_URL = (Deno.env.get('SITE_URL') ?? 'https://community.thefin.ai').replace(/\/$/, '');
const FROM = Deno.env.get('INVITE_FROM') ?? 'The Fin AI <community@thefin.ai>';
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}

type Laggard = {
  project_id: string;
  project_name: string;
  leader_id: string;
  leader_name: string;
  leader_email: string;
  year_month: string;
  hours: number;
  required: number;
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader) return json({ error: 'Not authenticated.' }, 401);

    const { leader_ids } = await req.json().catch(() => ({}));

    // Caller-scoped client — writing_laggards() enforces `manage_stater`.
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false } }
    );

    const { data, error: rpcErr } = await userClient.rpc('writing_laggards');
    if (rpcErr) return json({ error: rpcErr.message }, 403);

    let laggards = (data as Laggard[]) ?? [];
    if (Array.isArray(leader_ids) && leader_ids.length) {
      const want = new Set(leader_ids as string[]);
      laggards = laggards.filter((l) => want.has(l.leader_id));
    }

    if (!laggards.length) return json({ sent: 0, results: [] });

    if (!RESEND_API_KEY)
      return json({ sent: 0, results: [], email_error: 'RESEND_API_KEY is not set on the function.' });

    // group by leader so one person gets a single email listing their projects
    const byLeader = new Map<string, Laggard[]>();
    for (const l of laggards) {
      const arr = byLeader.get(l.leader_id) ?? [];
      arr.push(l);
      byLeader.set(l.leader_id, arr);
    }

    const results: { leader_id: string; email: string; ok: boolean; detail?: string }[] = [];
    let sent = 0;

    for (const [leader_id, rows] of byLeader) {
      const email = rows[0].leader_email;
      if (!email) { results.push({ leader_id, email: '', ok: false, detail: 'no email' }); continue; }
      const html = renderReminder({ name: rows[0].leader_name, ym: rows[0].year_month, rows });
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from: FROM,
          to: [email],
          subject: '✍️ Your first-author writing hours are due',
          html
        })
      });
      if (res.ok) { sent++; results.push({ leader_id, email, ok: true }); }
      else { results.push({ leader_id, email, ok: false, detail: await res.text() }); }
    }

    return json({ sent, results });
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});

function esc(s: string) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function renderReminder(opts: { name: string; ym: string; rows: Laggard[] }) {
  const first = esc((opts.name || '').split(/\s+/)[0] || 'there');
  const monthLabel = (() => {
    const [y, m] = opts.ym.split('-').map(Number);
    return new Date(y, m - 1, 1).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  })();
  const lines = opts.rows
    .map(
      (r) => `<tr><td style="padding:6px 0; font-size:14.5px; color:#c4ccd6;">
        <strong style="color:#e6edf3;">${esc(r.project_name)}</strong>
        <span style="color:#f0883e;"> — ${r.hours}/${r.required}h logged</span>
      </td></tr>`
    )
    .join('');

  return `<!doctype html>
<html>
  <body style="margin:0; padding:0; background:#0b0e13; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <div style="display:none; max-height:0; overflow:hidden; opacity:0;">Your ${esc(monthLabel)} first-author writing is behind.</div>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0b0e13; padding:32px 16px;">
      <tr><td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px; background:#12171f; border:1px solid #232c3a; border-radius:16px; overflow:hidden;">
          <tr><td style="padding:28px 32px 8px;">
            <div style="font-size:15px; font-weight:700; color:#e6edf3; letter-spacing:.2px;">
              <span style="display:inline-block; width:9px; height:9px; border-radius:50%; background:#16c784; margin-right:8px; vertical-align:middle;"></span>
              The&nbsp;Fin&nbsp;AI <span style="color:#8b949e; font-weight:500;">· Stater</span>
            </div>
          </td></tr>
          <tr><td style="padding:14px 32px 0;">
            <h1 style="margin:0; font-size:24px; line-height:1.25; color:#e6edf3;">A nudge on your writing, ${first}.</h1>
            <p style="margin:8px 0 0; font-size:15px; color:#f0883e; font-weight:600;">${esc(monthLabel)} first-author writing is running short.</p>
          </td></tr>
          <tr><td style="padding:18px 32px 0;">
            <p style="margin:0; font-size:15px; line-height:1.6; color:#c4ccd6;">
              As a project leader you carry a monthly first-author writing duty.
              These projects haven't reached this month's required hours yet:
            </p>
          </td></tr>
          <tr><td style="padding:10px 32px 0;">
            <table role="presentation" cellpadding="0" cellspacing="0" width="100%">${lines}</table>
          </td></tr>
          <tr><td style="padding:22px 32px 4px;">
            <a href="${SITE_URL}/projects" style="display:inline-block; background:#16c784; color:#04130c; text-decoration:none; font-weight:700; font-size:15px; padding:13px 26px; border-radius:10px;">Declare your hours&nbsp;→</a>
          </td></tr>
          <tr><td style="padding:18px 32px 28px;">
            <p style="margin:0; font-size:12.5px; line-height:1.6; color:#8b949e;">
              Open the project, find <strong style="color:#c4ccd6;">First-author writing</strong>, and declare this month's hours — declaring mints them into the pool.
            </p>
          </td></tr>
        </table>
        <p style="margin:16px 0 0; font-size:11.5px; color:#5b6675;">The&nbsp;Fin&nbsp;AI · invite-only research community</p>
      </td></tr>
    </table>
  </body>
</html>`;
}
