import { Link } from 'react-router-dom';
import { HeartPulse, BedDouble, Footprints, ShieldCheck } from 'lucide-react';
import { CLIENT_ID, signIn } from '../lib/auth';
import { GoogleButton, ThemeToggle } from '../components/ui';
import { BeatingHeart, EcgLine } from '../components/Pulse';

export default function Login({ message, onDemo }: { message?: string; onDemo: () => void }) {
  return (
    <main className="login">
      <div className="login-top"><span /><ThemeToggle /></div>
      <div className="login-hero">
        <img src="/icon.svg" alt="" className="login-logo" width="88" height="88" />
        <h1>PulseFolio</h1>
        <p className="muted">Your Fitbit health, beautifully clear.</p>
        <div className="login-pulse"><BeatingHeart bpm={72} size={30} /><EcgLine bpm={72} /></div>
      </div>
      <ul className="login-features">
        <li><span className="feat-icon heart"><HeartPulse size={20} aria-hidden="true" /></span><div><p className="strong">Live heart rate</p><p className="muted small">Hour by hour, resting heart rate and HRV</p></div></li>
        <li><span className="feat-icon sleep"><BedDouble size={20} aria-hidden="true" /></span><div><p className="strong">Sleep stages</p><p className="muted small">Deep, light and REM sleep every night</p></div></li>
        <li><span className="feat-icon move"><Footprints size={20} aria-hidden="true" /></span><div><p className="strong">Activity</p><p className="muted small">Steps, distance, calories and zone minutes</p></div></li>
      </ul>
      {message && <p className="login-msg" role="status">{message}</p>}
      <div className="login-actions">
        {CLIENT_ID
          ? <GoogleButton onClick={() => signIn('select_account')} />
          : <p className="login-msg">Google sign-in is not set up yet. You can still try the demo.</p>}
        <button className="btn ghost full" onClick={onDemo}>Try the demo</button>
        <p className="muted tiny center"><ShieldCheck size={14} aria-hidden="true" className="inline-icon" /> Use the Google account linked to your Fitbit or Pixel Watch. Your data goes straight from Google to this phone and is never stored on our servers. <Link to="/privacy" className="link-inline">Privacy</Link></p>
      </div>
    </main>
  );
}
