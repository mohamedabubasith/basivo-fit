import { Link } from 'react-router-dom';
import { Monitor, Sun, Moon, LogOut, RefreshCcw, ShieldCheck, BatteryMedium, Watch, ChevronRight, LogIn } from 'lucide-react';
import { setTheme, useTheme, type ThemePref } from '../lib/theme';
import { CLIENT_ID, signIn, signOut } from '../lib/auth';
import { useHealth } from '../lib/store';
import { GoogleButton, Header } from '../components/ui';

export default function Profile({ onExitDemo }: { onExitDemo: () => void }) {
  const { session, health, demo, leave } = useHealth();
  const { pref } = useTheme();
  const user = session?.user;
  const themes: { v: ThemePref; label: string; Icon: typeof Sun }[] = [
    { v: 'system', label: 'System', Icon: Monitor }, { v: 'light', label: 'Light', Icon: Sun }, { v: 'dark', label: 'Dark', Icon: Moon }
  ];
  const switchAccount = async () => { await signOut(true); signIn('select_account'); };

  return (
    <main className="page">
      <Header title="Profile" />
      <section className="card profile-card">
        {demo ? (
          <>
            <div className="avatar" aria-hidden="true">D</div>
            <div className="grow"><p className="strong">Demo mode</p><p className="muted small">Sign in to see your own Fitbit data.</p></div>
          </>
        ) : (
          <>
            {user?.picture ? <img src={user.picture} alt="" className="avatar" referrerPolicy="no-referrer" /> : <div className="avatar" aria-hidden="true">{(user?.name || '?')[0]}</div>}
            <div className="grow"><p className="strong ellipsis">{user?.name ?? 'Signed in'}</p><p className="muted small ellipsis">{user?.email}</p></div>
          </>
        )}
      </section>

      {demo ? (
        <section className="card">
          {CLIENT_ID ? <GoogleButton onClick={() => { onExitDemo(); signIn('select_account'); }} /> : <p className="muted small">Google sign-in is not set up yet.</p>}
          <button className="btn ghost full" onClick={onExitDemo}><LogIn size={18} aria-hidden="true" /> Back to start</button>
        </section>
      ) : health && (
        <section className="card">
          <h2><Watch size={18} aria-hidden="true" /> Devices</h2>
          {health.devices.length ? (
            <ul className="list">
              {health.devices.map((d, i) => (
                <li key={i} className="list-row static">
                  <BatteryMedium size={20} aria-hidden="true" />
                  <div className="grow"><p className="strong">{d.name}</p><p className="muted small">Synced {d.lastSync}</p></div>
                  <span className="mono">{d.battery !== null ? `${d.battery}%` : d.batteryStatus}</span>
                </li>
              ))}
            </ul>
          ) : <p className="muted small">No device found on this account.</p>}
        </section>
      )}

      <section className="card">
        <h2>Appearance</h2>
        <div className="segmented" role="radiogroup" aria-label="Theme">
          {themes.map(({ v, label, Icon }) => (
            <button key={v} role="radio" aria-checked={pref === v} className={`seg ${pref === v ? 'on' : ''}`}
              onClick={e => { const r = e.currentTarget.getBoundingClientRect(); setTheme(v, { x: r.left + r.width / 2, y: r.top + r.height / 2 }); }}>
              <Icon size={18} aria-hidden="true" />{label}
            </button>
          ))}
        </div>
      </section>

      {!demo && (
        <section className="card">
          <button className="btn ghost full" onClick={switchAccount}><RefreshCcw size={18} aria-hidden="true" /> Switch account</button>
          <button className="btn danger full" onClick={leave}><LogOut size={18} aria-hidden="true" /> Sign out</button>
          <p className="muted tiny">Signing out also removes PulseFolio's access to your Google Health data.</p>
        </section>
      )}

      <Link to="/privacy" className="card link-row"><ShieldCheck size={20} aria-hidden="true" /><span className="grow">Privacy</span><ChevronRight size={18} aria-hidden="true" /></Link>
      <p className="muted tiny center">PulseFolio 1.0 · Data from Google Health. Not a medical device.</p>
    </main>
  );
}
