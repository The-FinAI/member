// Supabase Edge Function: announce-release
//
// Sends a release-notes email to a staged audience: 'preview' (the flagged
// reviewers — Yuechen, Zhuoran) first, then 'all' (every member with an email).
//
// Security: the recipient list comes from release_recipients(audience), a
// SECURITY DEFINER function whose gate (manage_members) is in its WHERE clause —
// a caller without that capability gets an empty list and no mail goes out. The
// list is fetched with the *caller's* JWT, so this can't be used to spam.
//
// Request body: { audience?: 'all', recipient_ids?: string[], subject, body_html }
//   - recipient_ids: send only to these members (the preview stage's picked
//     reviewers). They're intersected with the gated 'all' list, so a caller
//     can never send to an id that isn't an authorised community member.
//   - audience: 'all' sends to everyone (the release stage).
//   body_html is the inner release-notes HTML (the admin writes it); the
//   function wraps it in the branded shell with a CTA to the site.
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

type Recipient = { member_id: string; full_name: string; email: string };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader) return json({ error: 'Not authenticated.' }, 401);

    const { audience, recipient_ids, subject, body_html } = await req.json().catch(() => ({}));
    const ids = Array.isArray(recipient_ids) ? (recipient_ids as string[]) : null;
    if (!ids?.length && audience !== 'all')
      return json({ error: "Provide recipient_ids (preview) or audience:'all'." }, 400);
    if (!subject || !body_html)
      return json({ error: 'subject and body_html are required.' }, 400);

    // Caller-scoped client — release_recipients() enforces manage_members, so an
    // unauthorised caller gets [] and nothing is sent.
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false } }
    );

    const { data, error: rpcErr } = await userClient.rpc('release_recipients', { p_audience: 'all' });
    if (rpcErr) return json({ error: rpcErr.message }, 403);

    let recipients = (data as Recipient[]) ?? [];
    // preview: narrow the authorised list to the picked ids (can't reach a
    // non-member id this way). release: keep the whole authorised list.
    const stage = ids?.length ? 'preview' : 'all';
    if (ids?.length) {
      const want = new Set(ids);
      recipients = recipients.filter((r) => want.has(r.member_id));
    }
    if (!recipients.length) return json({ sent: 0, total: 0, results: [], note: 'No recipients (or not authorised).' });

    if (!RESEND_API_KEY)
      return json({ sent: 0, total: recipients.length, results: [], email_error: 'RESEND_API_KEY is not set on the function.' });

    const results: { email: string; ok: boolean; detail?: string }[] = [];
    let sent = 0;

    for (const r of recipients) {
      const html = renderRelease({ name: r.full_name, subject, inner: body_html, audience: stage });
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from: FROM, to: [r.email], subject, html })
      });
      if (res.ok) { sent++; results.push({ email: r.email, ok: true }); }
      else { results.push({ email: r.email, ok: false, detail: await res.text() }); }
    }

    return json({ sent, total: recipients.length, audience: stage, results });
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});

function esc(s: string) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// The admin writes the inner release notes (body_html) as trusted HTML; we wrap
// it in the branded shell. (Only managers can call this, so body_html is trusted.)
function renderRelease(opts: { name: string; subject: string; inner: string; audience: string }) {
  const first = esc((opts.name || '').split(/\s+/)[0] || 'there');
  const previewBanner = opts.audience === 'preview'
    ? `<tr><td style="padding:0 32px;"><div style="background:#3a2d12; border:1px solid #6b5418; color:#e9c46a; font-size:12.5px; padding:8px 12px; border-radius:8px;">Preview for reviewers — please look it over before we send it to everyone.</div></td></tr>`
    : '';

  return `<!doctype html>
<html>
  <body style="margin:0; padding:0; background:#0b0e13; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <div style="display:none; max-height:0; overflow:hidden; opacity:0;">${esc(opts.subject)}</div>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0b0e13; padding:32px 16px;">
      <tr><td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px; background:#12171f; border:1px solid #232c3a; border-radius:16px; overflow:hidden;">
          <tr><td style="padding:28px 32px 8px;">
            <div style="font-size:15px; font-weight:700; color:#e6edf3; letter-spacing:.2px;">
              <span style="display:inline-block; width:9px; height:9px; border-radius:50%; background:#16c784; margin-right:8px; vertical-align:middle;"></span>
              The&nbsp;Fin&nbsp;AI <span style="color:#8b949e; font-weight:500;">· Community</span>
            </div>
          </td></tr>
          ${previewBanner}
          <tr><td style="padding:14px 32px 0;">
            <h1 style="margin:0; font-size:23px; line-height:1.3; color:#e6edf3;">${esc(opts.subject)}</h1>
            <p style="margin:10px 0 0; font-size:15px; color:#c4ccd6;">Hi ${first},</p>
          </td></tr>
          <tr><td style="padding:8px 32px 0; font-size:15px; line-height:1.65; color:#c4ccd6;">
            ${opts.inner}
          </td></tr>
          <tr><td style="padding:22px 32px 4px;">
            <a href="${SITE_URL}/projects" style="display:inline-block; background:#16c784; color:#04130c; text-decoration:none; font-weight:700; font-size:15px; padding:13px 26px; border-radius:10px;">Open the community&nbsp;→</a>
          </td></tr>
          <tr><td style="padding:18px 32px 28px;">
            <p style="margin:0; font-size:12.5px; line-height:1.6; color:#8b949e;">
              Replies to this email reach the community team. Tell us what's confusing — that feedback is how this gets built.
            </p>
          </td></tr>
        </table>
        <p style="margin:16px 0 0; font-size:11.5px; color:#5b6675;">The&nbsp;Fin&nbsp;AI · invite-only research community</p>
      </td></tr>
    </table>
  </body>
</html>`;
}
