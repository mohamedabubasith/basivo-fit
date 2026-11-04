import { Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';

export default function Privacy() {
  return (
    <main className="page doc">
      <Link to="/" className="back-link"><ArrowLeft size={20} aria-hidden="true" /> Back</Link>
      <h1>Privacy</h1>
      <p className="muted small">Last updated 4 November 2026</p>
      <h2>What PulseFolio reads</h2>
      <p>When you sign in with Google, you choose to let PulseFolio read your Google Health data: activity and fitness, sleep, health measurements (such as heart rate, oxygen and weight) and your connected devices. Access is read-only. PulseFolio cannot change or delete your data.</p>
      <h2>Where your data goes</h2>
      <p>Your data goes directly from Google to the PulseFolio app on your device. PulseFolio has no server that receives, stores or shares your health data. Nothing is sold or used for advertising.</p>
      <h2>What is saved on your device</h2>
      <p>Your sign-in token (valid for about one hour), your name, email and photo, and your theme choice are saved in your browser on this device so the app can work. Signing out deletes them and cancels PulseFolio's access with Google.</p>
      <h2>Google API Services User Data Policy</h2>
      <p>PulseFolio's use of information received from Google APIs follows the Google API Services User Data Policy, including the Limited Use requirements.</p>
      <h2>Not medical advice</h2>
      <p>PulseFolio shows your data to help you understand it. It is not a medical device and does not diagnose anything. Talk to a doctor about health concerns.</p>
      <h2>Contact</h2>
      <p>Questions about privacy: use the developer email shown on the Google sign-in screen.</p>
    </main>
  );
}
