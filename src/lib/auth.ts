// Google sign-in for a browser-only app (OAuth 2.0 implicit flow with redirect).
// The access token stays on this device and is only sent to Google.

export const CLIENT_ID = (import.meta.env.VITE_GOOGLE_CLIENT_ID as string | undefined) || '';

export const HEALTH_SCOPES = [
  'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly',
  'https://www.googleapis.com/auth/googlehealth.sleep.readonly',
  'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly',
  'https://www.googleapis.com/auth/googlehealth.settings.readonly'
];
const SCOPES = ['openid', 'email', 'profile', ...HEALTH_SCOPES];

const K = { session: 'pf.session', state: 'pf.state', silent: 'pf.silent', hint: 'pf.hint' };

export interface User { email: string; name: string; picture?: string }
export interface Session { token: string; expiresAt: number; scopes: string[]; user?: User }

const ls = {
  get: (k: string) => { try { return localStorage.getItem(k); } catch { return null; } },
  set: (k: string, v: string) => { try { localStorage.setItem(k, v); } catch { /* blocked */ } },
  del: (k: string) => { try { localStorage.removeItem(k); } catch { /* blocked */ } }
};
const ss = {
  get: (k: string) => { try { return sessionStorage.getItem(k); } catch { return null; } },
  set: (k: string, v: string) => { try { sessionStorage.setItem(k, v); } catch { /* blocked */ } },
  del: (k: string) => { try { sessionStorage.removeItem(k); } catch { /* blocked */ } }
};

const redirectUri = () => window.location.origin + '/';

export function getSession(): Session | null {
  const raw = ls.get(K.session);
  if (!raw) return null;
  try {
    const s = JSON.parse(raw) as Session;
    return s.expiresAt > Date.now() + 60_000 ? s : null;
  } catch { return null; }
}

export const missingScopes = (s: Session) => HEALTH_SCOPES.filter(x => !s.scopes.includes(x));

// Sends the user to Google. prompt: 'select_account' lets them pick or switch account,
// 'none' silently renews a session for someone who already agreed.
export function signIn(prompt: 'select_account' | 'consent' | 'none' = 'select_account') {
  if (!CLIENT_ID) throw new Error('Sign-in is not set up yet.');
  const state = crypto.getRandomValues(new Uint32Array(4)).join('-');
  ss.set(K.state, state);
  const p = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: redirectUri(),
    response_type: 'token',
    scope: SCOPES.join(' '),
    include_granted_scopes: 'true',
    state,
    prompt
  });
  const hint = ls.get(K.hint);
  if (prompt === 'none' && hint) p.set('login_hint', hint);
  window.location.assign('https://accounts.google.com/o/oauth2/v2/auth?' + p.toString());
}

export type RedirectResult = { kind: 'none' } | { kind: 'ok'; session: Session } | { kind: 'error'; error: string };

// Reads Google's answer from the URL after the redirect back to the app.
export async function handleRedirect(): Promise<RedirectResult> {
  const hash = window.location.hash.startsWith('#') ? window.location.hash.slice(1) : '';
  const p = new URLSearchParams(hash);
  if (!p.has('access_token') && !p.has('error')) return { kind: 'none' };
  // Sign-in started by the Basivo Fit phone app: hand the result straight back to the app
  // (its browser window is listening for basivofit://) without keeping anything here.
  if (/^app\.[0-9a-f]{32}$/.test(p.get('state') || '')) {
    window.location.replace('basivofit://auth#' + hash);
    return new Promise(() => { /* the app takes over */ });
  }
  history.replaceState(null, '', window.location.pathname + window.location.search);
  const expected = ss.get(K.state);
  ss.del(K.state);
  if (!expected || p.get('state') !== expected) return { kind: 'error', error: 'state_mismatch' };
  if (p.has('error')) return { kind: 'error', error: p.get('error') || 'unknown' };
  const session: Session = {
    token: p.get('access_token')!,
    expiresAt: Date.now() + Number(p.get('expires_in') || 3600) * 1000,
    scopes: (p.get('scope') || '').split(/\s+/).filter(Boolean)
  };
  try {
    const r = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', { headers: { Authorization: `Bearer ${session.token}` } });
    if (r.ok) {
      const u = await r.json();
      session.user = { email: u.email, name: u.name || u.email, picture: u.picture };
      ls.set(K.hint, u.email);
    }
  } catch { /* profile is optional */ }
  ls.set(K.session, JSON.stringify(session));
  ss.del(K.silent);
  return { kind: 'ok', session };
}

// Tries a silent renewal once per app visit when a previous session has expired.
export function trySilentRenew(): boolean {
  if (!CLIENT_ID || !ls.get(K.hint) || ss.get(K.silent)) return false;
  ss.set(K.silent, '1');
  signIn('none');
  return true;
}

export async function signOut(revoke = true) {
  const s = getSession();
  ls.del(K.session);
  ls.del(K.hint);
  if (revoke && s) {
    try { await fetch('https://oauth2.googleapis.com/revoke?token=' + encodeURIComponent(s.token), { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }); } catch { /* offline */ }
  }
}

export class AuthExpiredError extends Error {}
