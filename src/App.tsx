import { lazy, Suspense, useCallback, useEffect, useState } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { getSession, handleRedirect, missingScopes, trySilentRenew, type Session } from './lib/auth';
import { HealthProvider, useHealth } from './lib/store';
import { BottomNav, Skeleton } from './components/ui';
import Login from './pages/Login';
import Problem from './pages/Problem';
import { Today } from './pages/Tabs';

const Heart = lazy(() => import('./pages/Tabs').then(m => ({ default: m.Heart })));
const Sleep = lazy(() => import('./pages/Tabs').then(m => ({ default: m.Sleep })));
const ActivityTab = lazy(() => import('./pages/Tabs').then(m => ({ default: m.ActivityTab })));
const Profile = lazy(() => import('./pages/Profile'));
const Privacy = lazy(() => import('./pages/Privacy'));

const errorText: Record<string, string> = {
  access_denied: 'Sign-in was cancelled. To use PulseFolio, allow access to your Google Health data.',
  state_mismatch: 'Sign-in could not be verified. Please try again.',
  interaction_required: 'Please sign in again.',
  login_required: 'Please sign in again.',
  consent_required: 'Please sign in again and allow access.'
};

type Phase = { kind: 'loading' } | { kind: 'login'; message?: string } | { kind: 'app'; session: Session | null; demo: boolean };

function Shell({ onExitDemo }: { onExitDemo: () => void }) {
  const { problem } = useHealth();
  if (problem !== 'none') return <Problem />;
  return (
    <div className="app">
      <Suspense fallback={<main className="page"><Skeleton h={240} /></main>}>
        <Routes>
          <Route path="/" element={<Today />} />
          <Route path="/heart" element={<Heart />} />
          <Route path="/sleep" element={<Sleep />} />
          <Route path="/activity" element={<ActivityTab />} />
          <Route path="/profile" element={<Profile onExitDemo={onExitDemo} />} />
          <Route path="/privacy" element={<Privacy />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
      <BottomNav />
    </div>
  );
}

export default function App() {
  const [phase, setPhase] = useState<Phase>({ kind: 'loading' });

  useEffect(() => {
    (async () => {
      const r = await handleRedirect();
      if (r.kind === 'ok') {
        const missing = missingScopes(r.session);
        if (missing.length === 4) { setPhase({ kind: 'login', message: errorText.access_denied }); return; }
        setPhase({ kind: 'app', session: r.session, demo: false });
        return;
      }
      if (r.kind === 'error') { setPhase({ kind: 'login', message: errorText[r.error] ?? 'Sign-in failed. Please try again.' }); return; }
      const s = getSession();
      if (s) { setPhase({ kind: 'app', session: s, demo: false }); return; }
      if (trySilentRenew()) return;
      setPhase({ kind: 'login' });
    })();
  }, []);

  const onSignedOut = useCallback((message?: string) => setPhase({ kind: 'login', message }), []);
  const startDemo = useCallback(() => setPhase({ kind: 'app', session: null, demo: true }), []);
  const exitDemo = useCallback(() => setPhase({ kind: 'login' }), []);

  return (
    <BrowserRouter>
      {phase.kind === 'loading' && <main className="splash" aria-busy="true"><img src="/icon.svg" alt="PulseFolio" width="72" height="72" className="splash-logo" /></main>}
      {phase.kind === 'login' && (
        <Routes>
          <Route path="/privacy" element={<Suspense fallback={null}><Privacy /></Suspense>} />
          <Route path="*" element={<Login message={phase.message} onDemo={startDemo} />} />
        </Routes>
      )}
      {phase.kind === 'app' && (
        <HealthProvider key={phase.demo ? 'demo' : 'live'} session={phase.session} demo={phase.demo} onSignedOut={onSignedOut}>
          <Shell onExitDemo={exitDemo} />
        </HealthProvider>
      )}
    </BrowserRouter>
  );
}
