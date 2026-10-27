#!/usr/bin/env node
// Provisionne un compte admin Supabase (Auth + profiles.role).
// Usage : node scripts/create-admin.mjs [--email ...] [--password ...]
// Secrets lus depuis .env.admin ou l'environnement. Ne jamais committer ce fichier .env.admin.

import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

function loadEnvFile(path) {
  if (!existsSync(path)) return {};
  const out = {};
  for (const raw of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const index = line.indexOf('=');
    if (index < 1) continue;
    out[line.slice(0, index).trim()] = line.slice(index + 1).trim();
  }
  return out;
}

function argValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

const fileEnv = loadEnvFile(resolve('.env.admin'));
const env = { ...fileEnv, ...process.env };
const url = env.SUPABASE_URL;
const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY;
const email = argValue('--email') ?? env.ADMIN_EMAIL;
const password = argValue('--password') ?? env.ADMIN_PASSWORD;

if (!url || !serviceKey) {
  console.error('SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont requis (.env.admin).');
  process.exit(1);
}
if (!email || !password || password.length < 8) {
  console.error('ADMIN_EMAIL et ADMIN_PASSWORD (>= 8 caractères) sont requis.');
  process.exit(1);
}

const headers = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  'Content-Type': 'application/json',
};

async function request(path, options = {}) {
  const response = await fetch(`${url}${path}`, { headers, ...options });
  const text = await response.text();
  let body = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }
  if (!response.ok) {
    const message = typeof body === 'string' ? body : JSON.stringify(body);
    throw new Error(`${options.method ?? 'GET'} ${path} -> ${response.status}: ${message}`);
  }
  return body;
}

async function findUserByEmail(target) {
  let page = 1;
  for (;;) {
    const result = await request(`/auth/v1/admin/users?page=${page}&per_page=1000`);
    const users = result?.users ?? [];
    const found = users.find((user) => user.email?.toLowerCase() === target.toLowerCase());
    if (found) return found;
    if (users.length < 1000) return null;
    page += 1;
  }
}

let user;
try {
  user = await request('/auth/v1/admin/users', {
    method: 'POST',
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
} catch (error) {
  user = await findUserByEmail(email);
  if (!user) throw error;
}

await request('/rest/v1/profiles?on_conflict=id', {
  method: 'POST',
  headers: { ...headers, Prefer: 'resolution=merge-duplicates,return=representation' },
  body: JSON.stringify({ id: user.id, role: 'admin' }),
});

console.log(`Admin prêt : ${email} (${user.id})`);
