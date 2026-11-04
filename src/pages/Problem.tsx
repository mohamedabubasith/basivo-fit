import { WatchIcon, KeyRound, AlertCircle } from 'lucide-react';
import { signIn, signOut } from '../lib/auth';
import { useHealth } from '../lib/store';
import { GoogleButton } from '../components/ui';

export default function Problem() {
  const { problem, session, message, reload, leave } = useHealth();
  const email = session?.user?.email;
  const switchAccount = async () => { await signOut(true); signIn('select_account'); };

  if (problem === 'no-device') return (
    <main className="problem">
      <span className="problem-icon"><WatchIcon size={36} aria-hidden="true" /></span>
      <h1>No device connected</h1>
      <p className="muted">{email ? <><b>{email}</b> does not have</> : 'This Google account does not have'} a Fitbit or Pixel Watch connected.</p>
      <p className="muted small">Sign out and sign in with the Google account you use in the Fitbit or Google Health app.</p>
      <GoogleButton onClick={switchAccount} label="Sign in with another account" />
      <button className="btn ghost full" onClick={reload}>Check again</button>
      <button className="btn text" onClick={leave}>Sign out</button>
    </main>
  );
  if (problem === 'permission') return (
    <main className="problem">
      <span className="problem-icon warn"><KeyRound size={36} aria-hidden="true" /></span>
      <h1>Permission needed</h1>
      <p className="muted">PulseFolio needs permission to read your activity, sleep, heart and device data. Please sign in again and tick all the boxes.</p>
      <GoogleButton onClick={() => signIn('consent')} label="Allow access with Google" />
      <button className="btn text" onClick={leave}>Sign out</button>
    </main>
  );
  return (
    <main className="problem">
      <span className="problem-icon warn"><AlertCircle size={36} aria-hidden="true" /></span>
      <h1>Could not load your data</h1>
      <p className="muted">{message}</p>
      <button className="btn primary full" onClick={reload}>Try again</button>
      <button className="btn text" onClick={leave}>Sign out</button>
    </main>
  );
}
