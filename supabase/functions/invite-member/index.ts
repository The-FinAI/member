// Supabase Edge Function: invite-member
//
// Pre-creates an invited member AND sends them a branded invitation letter.
//
// Security model: the member row is inserted with the *caller's* JWT, so the
// existing RLS policy on `member` (which requires the `manage_members`
// capability) is what authorises the action. If the caller can't insert, they
// get a permission error and no email is sent — so this can't be abused to
// spray arbitrary invitation emails.
//
// Required secret:  RESEND_API_KEY   (set via `supabase secrets set`)
// Optional secrets: INVITE_FROM      (e.g. "The Fin AI <community@thefin.ai>")
//                   SITE_URL         (e.g. "https://community.thefin.ai")
// Auto-provided by the platform: SUPABASE_URL, SUPABASE_ANON_KEY

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader) return json({ error: 'Not authenticated.' }, 401);

    const { full_name, email, affiliation, position_id, inviter_name } = await req.json().catch(() => ({}));
    if (!full_name?.trim() || !email?.trim())
      return json({ error: 'Name and email are required.' });

    const cleanEmail = email.trim();
    const cleanName = full_name.trim();

    // Caller-scoped client — RLS on `member` enforces `manage_members`.
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false } }
    );

    const { data: m, error: insErr } = await userClient
      .from('member')
      .insert({
        full_name: cleanName,
        email: cleanEmail,
        affiliation: affiliation || null,
        status: 'invited'
      })
      .select('id')
      .single();

    if (insErr) {
      const msg = insErr.code === '23505'
        ? 'That email is already on the member list.'
        : insErr.message;
      return json({ error: msg });
    }

    if (position_id) {
      // Non-fatal: a failed position assignment shouldn't block the invite.
      await userClient.from('member_position').insert({ member_id: m.id, position_id });
    }

    if (!RESEND_API_KEY) {
      return json({ id: m.id, email_sent: false, email_error: 'RESEND_API_KEY is not set on the function.' });
    }

    const link = `${SITE_URL}/login?email=${encodeURIComponent(cleanEmail)}&invited=1`;
    const html = renderInvite({ fullName: cleanName, link, inviterName: (inviter_name || '').trim() });

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: FROM,
        to: [cleanEmail],
        subject: '🎟️ Your seat at The Fin AI just opened',
        html
      })
    });

    if (!res.ok) {
      // The member exists; only the email failed. Surface it so the admin can retry.
      const detail = await res.text();
      return json({ id: m.id, email_sent: false, email_error: detail });
    }

    return json({ id: m.id, email_sent: true });
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});

function esc(s: string) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function renderInvite(opts: { fullName: string; link: string; inviterName: string }) {
  const first = esc(opts.fullName.split(/\s+/)[0] || opts.fullName);
  const link = opts.link;
  const signoff = opts.inviterName
    ? `— ${esc(opts.inviterName)}, on behalf of The&nbsp;Fin&nbsp;AI`
    : '— The&nbsp;Fin&nbsp;AI';

  return `<!doctype html>
<html>
  <body style="margin:0; padding:0; background:#0b0e13; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <div style="display:none; max-height:0; overflow:hidden; opacity:0;">The ledger's been opened in your name — step inside.</div>
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
            <h1 style="margin:0; font-size:26px; line-height:1.25; color:#e6edf3;">You're invited, ${first}.</h1>
            <p style="margin:8px 0 0; font-size:15px; color:#16c784; font-weight:600;">The ledger's been opened in your name.</p>
          </td></tr>
          <tr><td style="padding:18px 32px 0;">
            <p style="margin:0; font-size:15px; line-height:1.6; color:#c4ccd6;">
              The&nbsp;Fin&nbsp;AI is a research community where financial-AI work actually ships —
              datasets, benchmarks, models, agents — built by people who'd rather collaborate than compete.
              We run on a little stake economy called <strong style="color:#e6edf3;">STR</strong>: you earn it,
              stake it on projects you believe in, and share in what they produce. Think of it as a guild hall
              with a trading floor attached.
            </p>
          </td></tr>
          <tr><td style="padding:18px 32px 0;">
            <table role="presentation" cellpadding="0" cellspacing="0" style="font-size:14.5px; line-height:1.5; color:#c4ccd6;">
              <tr><td style="padding:3px 0;">🧪&nbsp;&nbsp;Join or launch projects with real datasets &amp; compute</td></tr>
              <tr><td style="padding:3px 0;">🏅&nbsp;&nbsp;Earn your craft in the Guild — get certified, mentor others</td></tr>
              <tr><td style="padding:3px 0;">💎&nbsp;&nbsp;A starter grant of STR is already waiting in your wallet</td></tr>
            </table>
          </td></tr>
          <tr><td style="padding:26px 32px 4px;">
            <a href="${link}" style="display:inline-block; background:#16c784; color:#04130c; text-decoration:none; font-weight:700; font-size:15px; padding:13px 26px; border-radius:10px;">Step inside&nbsp;→</a>
          </td></tr>
          <tr><td style="padding:16px 32px 0;">
            <p style="margin:0; font-size:12.5px; line-height:1.6; color:#8b949e;">
              This invitation is tied to your email. Click above, and we'll send a secure one-time
              sign-in link — there's no password to remember. If the button doesn't work, paste this into your browser:<br>
              <a href="${link}" style="color:#6aa6ff; word-break:break-all;">${esc(link)}</a>
            </p>
          </td></tr>
          <tr><td style="padding:22px 32px 28px;">
            <p style="margin:0; font-size:14px; color:#c4ccd6;">See you on the floor,<br><strong style="color:#e6edf3;">${signoff}</strong></p>
          </td></tr>
        </table>
        <p style="margin:16px 0 0; font-size:11.5px; color:#5b6675;">The&nbsp;Fin&nbsp;AI · invite-only research community</p>
      </td></tr>
    </table>
  </body>
</html>`;
}
