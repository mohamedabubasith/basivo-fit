import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { AuthExpiredError, getSession, signOut, trySilentRenew, type Session } from './auth';
import { fetchHealth, NoDeviceError, PermissionError } from '../data/health';
import { fetchLatestHr } from '../data/heart';
import { demoHealth } from '../data/demo';
import type { Health } from '../data/types';

export type Problem = 'none' | 'no-device' | 'permission' | 'error';

interface Ctx {
  session: Session | null;
  demo: boolean;
  health?: Health;
  problem: Problem;
  message: string;
  loading: boolean;
  reload: () => void;
  leave: () => Promise<void>;
}

const HealthCtx = createContext<Ctx | null>(null);
export const useHealth = () => useContext(HealthCtx)!;

export function HealthProvider({ session, demo, onSignedOut, children }:
  { session: Session | null; demo: boolean; onSignedOut: (msg?: string) => void; children: React.ReactNode }) {
  const [health, setHealth] = useState<Health | undefined>(demo ? demoHealth : undefined);
  const [problem, setProblem] = useState<Problem>('none');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(!demo);
  const busy = useRef(false);

  const reload = useCallback(async () => {
    if (demo) { setHealth(demoHealth); return; }
    if (busy.current) return;
    const s = getSession();
    if (!s) { if (!trySilentRenew()) onSignedOut('Your session has ended. Please sign in again.'); return; }
    busy.current = true; setLoading(true);
    try {
      setHealth(await fetchHealth(s.token));
      setProblem('none'); setMessage('');
    } catch (e) {
      if (e instanceof AuthExpiredError) {
        await signOut(false);
        if (!trySilentRenew()) onSignedOut('Your session has ended. Please sign in again.');
      } else if (e instanceof NoDeviceError) { setProblem('no-device'); setMessage(e.message); }
      else if (e instanceof PermissionError) { setProblem('permission'); setMessage(e.message); }
      else { console.warn('PulseFolio load failed', e); setProblem('error'); setMessage('Could not load your health data. Check your internet and try again.'); }
    } finally { busy.current = false; setLoading(false); }
  }, [demo, onSignedOut]);

  useEffect(() => { reload(); }, [reload]);
  useEffect(() => {
    if (demo) return;
    const tick = () => { if (document.visibilityState === 'visible') reload(); };
    const id = setInterval(tick, 60_000);
    document.addEventListener('visibilitychange', tick);
    return () => { clearInterval(id); document.removeEventListener('visibilitychange', tick); };
  }, [reload, demo]);

  // Live heart rate: check for a newer reading every 20 seconds while the app is open.
  useEffect(() => {
    if (demo) return;
    const id = setInterval(async () => {
      const s = getSession();
      if (!s || document.visibilityState !== 'visible') return;
      try {
        const r = await fetchLatestHr(s.token);
        if (r) setHealth(h => h && (!h.heart.now?.at || r.at >= h.heart.now.at)
          ? { ...h, heart: { ...h.heart, now: { bpm: r.bpm, at: r.at, time: new Date(r.at).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' }) } } } : h);
      } catch { /* next tick will retry */ }
    }, 20_000);
    return () => clearInterval(id);
  }, [demo]);

  const leave = useCallback(async () => { await signOut(true); onSignedOut(); }, [onSignedOut]);

  return <HealthCtx.Provider value={{ session, demo, health, problem, message, loading, reload, leave }}>{children}</HealthCtx.Provider>;
}
