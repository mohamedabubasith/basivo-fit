import { Link } from 'react-router-dom';
import { Sparkles, ChevronRight, HeartPulse, Info } from 'lucide-react';
import { useHealth } from '../lib/store';
import { tip } from '../data/health';
import { Header, LiveBadge, RefreshButton, Skeleton } from '../components/ui';
import { AzmCard, DayStats, DeviceStrip, HourlyCard, HeartCard, SleepCard, StepsCard, Vitals, WeekSteps } from '../components/sections';
import { RangeChart, Sparkline } from '../components/Charts';
import HeartDetail from '../components/HeartDetail';
import SleepDetail from '../components/SleepDetail';

function useData() {
  const ctx = useHealth();
  return ctx;
}

function Sub() {
  const { health, demo } = useHealth();
  if (!health) return null;
  return <><LiveBadge live={!demo} time={!demo ? `updated ${health.updatedAt}` : undefined} /></>;
}

function Loading({ title }: { title: string }) {
  return <main className="page"><Header title={title} /><Skeleton h={220} /><Skeleton h={160} /></main>;
}

export function Today() {
  const { health: h, session, loading, reload, demo } = useData();
  if (!h) return <Loading title="Today" />;
  const hour = new Date().getHours();
  const first = (session?.user?.name || '').split(' ')[0];
  const greet = (hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening') + (first ? `, ${first}` : '');
  return (
    <main className="page">
      <Header title={greet} subtitle={<Sub />} right={!demo && <RefreshButton loading={loading} onClick={reload} />} />
      <DeviceStrip h={h} />
      <div className="card ai-note"><Sparkles size={18} aria-hidden="true" /><p>{tip(h)}</p></div>
      <Link to="/heart" className="link-card"><HeartCard h={h} /></Link>
      <StepsCard h={h} />
      <DayStats h={h} />
      <Link to="/sleep" className="link-card"><SleepCard h={h} /></Link>
      <Vitals h={h} />
      {demo && <p className="muted tiny center">You are viewing demo data. Sign in with Google on the Profile tab to see your own.</p>}
    </main>
  );
}

export function Heart() {
  const { health: h, loading, reload, demo } = useData();
  if (!h) return <Loading title="Heart" />;
  return (
    <main className="page">
      <Header title="Heart" subtitle={<Sub />} right={!demo && <RefreshButton loading={loading} onClick={reload} />} />
      <HeartCard h={h} />
      <HeartDetail />
      {h.heart.resting.length > 1 && (
        <section className="card"><div className="row between"><h2>Resting heart rate</h2><span className="mono">{h.heart.resting[h.heart.resting.length - 1].bpm} bpm</span></div>
          <Sparkline data={h.heart.resting.map(r => r.bpm)} up={false} height={60} />
          <p className="muted small">A lower resting heart rate usually means better fitness. Watch the trend, not single days.</p></section>
      )}
      {h.heart.hrv.length > 1 && (
        <section className="card"><div className="row between"><h2>Heart rate variability</h2><span className="mono">{h.heart.hrv[h.heart.hrv.length - 1].ms} ms</span></div>
          <Sparkline data={h.heart.hrv.map(r => r.ms)} up height={60} />
          <p className="muted small">HRV is measured while you sleep. Higher than your usual level often means you are well rested.</p></section>
      )}
      <p className="muted tiny center"><Info size={12} aria-hidden="true" className="inline-icon" /> Not medical advice. Talk to a doctor about any health concerns.</p>
    </main>
  );
}

export function Sleep() {
  const { health: h, loading, reload, demo } = useData();
  if (!h) return <Loading title="Sleep" />;
  return (
    <main className="page">
      <Header title="Sleep" subtitle={<Sub />} right={!demo && <RefreshButton loading={loading} onClick={reload} />} />
      <SleepDetail h={h} />
      <SleepCard h={h} full />
      <section className="card">
        <h2>About sleep stages</h2>
        <ul className="explain">
          <li><span className="dot deep" aria-hidden="true" /><p><b>Deep</b> sleep helps your body recover.</p></li>
          <li><span className="dot light" aria-hidden="true" /><p><b>Light</b> sleep is most of the night.</p></li>
          <li><span className="dot rem" aria-hidden="true" /><p><b>REM</b> sleep is when you dream and helps memory.</p></li>
          <li><span className="dot awake" aria-hidden="true" /><p><b>Awake</b> short wake-ups are normal.</p></li>
        </ul>
      </section>
      {h.vitals.spo2 && (
        <section className="card"><h2>Overnight blood oxygen</h2><p className="big-num sm">{h.vitals.spo2.avg}%</p><p className="muted small">Ranged from {h.vitals.spo2.low}% to {h.vitals.spo2.high}% last night.</p></section>
      )}
    </main>
  );
}

export function ActivityTab() {
  const { health: h, loading, reload, demo } = useData();
  if (!h) return <Loading title="Activity" />;
  return (
    <main className="page">
      <Header title="Activity" subtitle={<Sub />} right={!demo && <RefreshButton loading={loading} onClick={reload} />} />
      <StepsCard h={h} />
      <HourlyCard h={h} />
      <WeekSteps h={h} />
      <AzmCard h={h} />
      {h.heart.hourly.length > 1 && (
        <section className="card"><h2><HeartPulse size={18} aria-hidden="true" /> Heart rate during the day</h2>
          <RangeChart points={h.heart.hourly.map(p => ({ label: p.hour, avg: p.avg, min: p.min, max: p.max }))} height={130} />
          <Link to="/heart" className="link">Heart details <ChevronRight size={16} aria-hidden="true" /></Link></section>
      )}
    </main>
  );
}
