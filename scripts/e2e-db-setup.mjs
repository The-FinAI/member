// Real-DB e2e bootstrap: mint HS256 JWTs for anon/service, create the test
// users in GoTrue (password login), then link member.auth_user_id by email.
// Usage: node scripts/e2e-db-setup.mjs mint   -> prints ANON_KEY/SERVICE_KEY
//        node scripts/e2e-db-setup.mjs users  -> creates users (needs env)
import crypto from 'node:crypto';
import { execSync } from 'node:child_process';

const SECRET = process.env.E2E_JWT_SECRET ?? 'super-secret-jwt-token-with-at-least-32-characters';
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (payload) => {
  const body = `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64(payload)}`;
  return `${body}.${crypto.createHmac('sha256', SECRET).update(body).digest('base64url')}`;
};
const exp = Math.floor(Date.now() / 1000) + 86400 * 30;

if (process.argv[2] === 'mint') {
  console.log(`ANON_KEY=${jwt({ role: 'anon', iss: 'e2e', exp })}`);
  console.log(`SERVICE_KEY=${jwt({ role: 'service_role', iss: 'e2e', exp })}`);
  process.exit(0);
}

const GOTRUE = process.env.GOTRUE_URL ?? 'http://127.0.0.1:9999';
const SERVICE = jwt({ role: 'service_role', iss: 'e2e', exp });
const USERS = ['chen@e2e.local', 'li@e2e.local', 'wu@e2e.local', 'chan@e2e.local', 'admin@e2e.local', 'orphan@e2e.local'];
const LOCAL = process.env.LOCAL ?? 'postgresql://postgres:postgres@127.0.0.1:5432/postgres';

for (const email of USERS) {
  const r = await fetch(`${GOTRUE}/admin/users`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${SERVICE}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'e2e-password', email_confirm: true })
  });
  const u = await r.json();
  if (!r.ok) { console.error(email, u); process.exit(1); }
  console.log('created', email, u.id);
  if (email !== 'orphan@e2e.local') {
    execSync(`psql "${LOCAL}" -v ON_ERROR_STOP=1 -c "update member set auth_user_id='${u.id}' where email='${email}'"`);
  }
}
console.log('e2e users ready');
