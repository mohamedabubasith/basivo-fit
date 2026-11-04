import '../extra.css';
import { Footprints, Flame, Dumbbell, Clock, HeartPulse, Droplets, BatteryMedium, MapPin, Wind, Thermometer, Scale, Activity, Zap, Moon } from 'lucide-react';
import type { Health } from '../data/types';
import { isNap, mainSleep } from '../data/health';
import { useCountUp } from '../lib/motion';
import { hm, num0 } from '../lib/format';
import { Bars, RangeChart, Ring, Sparkline } from './Charts';
import { BeatingHeart, EcgLine } from './Pulse';
import { Tile } from './ui';

export function HeartCard({ h, full = false }: { h: Health; full?: boolean }) {
  const now = h.heart.now;
  const bpm = useCountUp(now?.bpm ?? 0, 900);
  const lastRest = h.heart.resting[h.heart.resting.length - 1];
  const lastHrv = h.heart.hrv[h.heart.hrv.length - 1];
  return (
    <section className="card heart-hero" aria-labelledby="hr-title">
      <h2 id="hr-title">Heart rate</h2>
      <div className="heart-now">
        <BeatingHeart bpm={now?.bpm ?? 0} size={40} />
        <div>
          <p className="big-num">{now ? Math.round(bpm) : '--'}<span className="unit"> bpm</span></p>
          <p className="muted small">{now ? `Last reading at ${now.time}` : 'No reading yet'}</p>
        </div>
      </div>
      <EcgLine bpm={now?.bpm ?? 60} />
      {full && <>
        <RangeChart points={h.heart.hourly.map(p => ({ label: p.hour, avg: p.avg, min: p.min, max: p.max }))} />
        <p className="muted small">The line is your hourly average. The shading shows your lowest to highest reading in each hour.</p>
      </>}
      <dl className="kv three">
        <div><dt>Resting</dt><dd className="mono">{lastRest ? `${lastRest.bpm} bpm` : '--'}</dd></div>
        <div><dt>Highest today</dt><dd className="mono">{h.heart.hourly.length ? `${Math.max(...h.heart.hourly.map(p => p.max))} bpm` : '--'}</dd></div>
        <div><dt>HRV</dt><dd className="mono">{lastHrv ? `${lastHrv.ms} ms` : '--'}</dd></div>
      </dl>
    </section>
  );
}

export function StepsCard({ h }: { h: Health }) {
  const steps = useCountUp(h.activity.stepsToday);
  const left = Math.max(h.stepGoal - h.activity.stepsToday, 0);
  return (
    <section className="card steps-card" aria-labelledby="steps-title">
      <Ring value={h.activity.stepsToday} max={h.stepGoal} size={140} stroke={13}>
        <Footprints size={20} className="muted" aria-hidden="true" />
        <span className="big-num sm">{num0(steps)}</span>
        <span className="muted small">of {num0(h.stepGoal)}</span>
      </Ring>
      <div className="grow">
        <h2 id="steps-title">Steps today</h2>
        <p className="muted small">{left > 0 ? `${num0(left)} more to reach your goal.` : 'Goal reached. Well done.'}</p>
        <ul className="mini-stats">
          <li><MapPin size={18} aria-hidden="true" /><span className="muted small">Distance</span><span className="mono">{h.activity.distanceKm} km</span></li>
          <li><Flame size={18} aria-hidden="true" /><span className="muted small">Active cal</span><span className="mono">{num0(h.activity.activeKcal)}</span></li>
          <li><Zap size={18} aria-hidden="true" /><span className="muted small">Zone min</span><span className="mono">{h.activity.azm.total}</span></li>
        </ul>
      </div>
    </section>
  );
}

export function SleepCard({ h, full = false }: { h: Health; full?: boolean }) {
  const night = mainSleep(h.sleep);
  if (!night) return <section className="card"><h2><Moon size={18} aria-hidden="true" /> Sleep</h2><p className="muted">No sleep recorded yet. Wear your tracker to bed to see your sleep stages.</p></section>;
  const nights = h.sleep.filter(n => !isNap(n));
  const naps = h.sleep.filter(isNap);
  const avg = nights.length ? nights.reduce((a, n) => a + n.minutes, 0) / nights.length : 0;
  const stages = [
    { key: 'deep', label: 'Deep', v: night.deep }, { key: 'light', label: 'Light', v: night.light },
    { key: 'rem', label: 'REM', v: night.rem }, { key: 'awake', label: 'Awake', v: night.awake }
  ];
  const total = stages.reduce((a, s) => a + s.v, 0) || 1;
  return (
    <section className="card" aria-labelledby="sleep-title">
      <div className="row between">
        <h2 id="sleep-title"><Moon size={18} aria-hidden="true" /> Last night</h2>
        <span className="muted small mono">{night.bedtime} to {night.wake}</span>
      </div>
      <p className="big-num sm">{hm(night.minutes)}</p>
      {night.longestWake && night.longestWake.minutes >= 20 && <p className="sleep-wake small">Awake {night.longestWake.minutes} min around {night.longestWake.at}</p>}
      {nights.length > 1 && <p className="muted small">Average {hm(avg)} over {nights.length} nights</p>}
      <div className="stage-bar" role="img" aria-label={stages.map(s => `${s.label} ${s.v} minutes`).join(', ')}>
        {stages.map(s => <div key={s.key} className={`stage ${s.key}`} style={{ width: `${(s.v / total) * 100}%` }} />)}
      </div>
      <ul className="stage-legend">
        {stages.map(s => <li key={s.key}><span className={`dot ${s.key}`} aria-hidden="true" />{s.label}<span className="mono">{s.v} min</span></li>)}
      </ul>
      {full && nights.length > 1 && <Bars data={nights.map(n => +(n.minutes / 60).toFixed(1))} labels={nights.map(n => n.date)} goal={7} format={v => `${v} h`} height={120} />}
      {full && naps.length > 0 && <p className="muted small">Naps: {naps.map(n => `${n.date} ${n.bedtime}, ${n.minutes} min`).join(' · ')}</p>}
    </section>
  );
}

export function WeekSteps({ h }: { h: Health }) {
  if (h.activity.stepsWeek.length < 2) return null;
  return (
    <section className="card" aria-labelledby="week-title">
      <h2 id="week-title">Steps by day</h2>
      <Bars data={h.activity.stepsWeek.map(d => d.steps)} labels={h.activity.stepsWeek.map(d => d.date)} goal={h.stepGoal} format={num0} />
    </section>
  );
}

export function Vitals({ h }: { h: Health }) {
  const lastRest = h.heart.resting[h.heart.resting.length - 1];
  const lastHrv = h.heart.hrv[h.heart.hrv.length - 1];
  return (
    <section aria-labelledby="vitals-title">
      <h2 id="vitals-title">Body and vitals</h2>
      <div className="tiles">
        <Tile icon={<Droplets size={18} />} label="Blood oxygen" value={h.vitals.spo2 ? `${h.vitals.spo2.avg}%` : '--'} sub={h.vitals.spo2 ? `${h.vitals.spo2.low} to ${h.vitals.spo2.high}% overnight` : 'No data yet'} />
        <Tile icon={<Wind size={18} />} label="Breathing rate" value={h.vitals.respRate ? `${h.vitals.respRate}` : '--'} sub="breaths per minute" />
        <Tile icon={<Thermometer size={18} />} label="Skin temp" value={h.vitals.skinTempC ? `${h.vitals.skinTempC}°C` : '--'} sub="during sleep" />
        <Tile icon={<Scale size={18} />} label="Weight" value={h.vitals.weightKg ? `${h.vitals.weightKg} kg` : '--'} sub="last logged" />
        <Tile icon={<Activity size={18} />} label="Resting heart" value={lastRest ? `${lastRest.bpm} bpm` : '--'}
          sub={h.heart.resting.length > 1 ? <Sparkline data={h.heart.resting.map(r => r.bpm)} up={false} height={22} /> : 'trend builds daily'} />
        <Tile icon={<Zap size={18} />} label="HRV" value={lastHrv ? `${lastHrv.ms} ms` : '--'}
          sub={h.heart.hrv.length > 1 ? <Sparkline data={h.heart.hrv.map(r => r.ms)} up height={22} /> : 'trend builds daily'} />
      </div>
    </section>
  );
}

export function DeviceStrip({ h }: { h: Health }) {
  const d = h.devices[0];
  if (!d) return null;
  return (
    <div className="device-strip">
      <BatteryMedium size={16} aria-hidden="true" />
      <span>{d.name}{d.battery !== null ? ` · ${d.battery}%` : ''}</span>
      <span className="muted">synced {d.lastSync}</span>
    </div>
  );
}

export function AzmCard({ h }: { h: Health }) {
  const z = h.activity.azm;
  const rows = [{ k: 'Fat burn', v: z.fatBurn, cls: 'fat' }, { k: 'Cardio', v: z.cardio, cls: 'cardio' }, { k: 'Peak', v: z.peak, cls: 'peak' }];
  const max = Math.max(1, ...rows.map(r => r.v));
  return (
    <section className="card" aria-labelledby="azm-title">
      <div className="row between"><h2 id="azm-title"><Zap size={18} aria-hidden="true" /> Active Zone Minutes</h2><span className="mono strong">{z.total}</span></div>
      <p className="muted small">Cardio and peak minutes count double.</p>
      <ul className="zones">
        {rows.map(r => (
          <li key={r.k}><span className="small">{r.k}</span>
            <span className="zone-track"><span className={`zone-fill ${r.cls}`} style={{ width: `${(r.v / max) * 100}%` }} /></span>
            <span className="mono small">{r.v} min</span></li>
        ))}
      </ul>
    </section>
  );
}

export { BeatingHeart };

export function DayStats({ h }: { h: Health }) {
  const a = h.activity, r = h.heart.todayRange;
  return (
    <section aria-labelledby="day-title">
      <h2 id="day-title">Today at a glance</h2>
      <div className="tiles">
        <Tile icon={<Flame size={18} />} label="Calories burned" value={a.totalKcal !== null ? num0(a.totalKcal) : '--'} sub={`${num0(a.activeKcal)} from activity`} />
        <Tile icon={<HeartPulse size={18} />} label="Heart rate" value={r ? `${r.min} to ${r.max}` : '--'} sub={r ? `bpm today, average ${r.avg}` : 'No readings yet'} />
        <Tile icon={<Clock size={18} />} label="Hourly activity" value={`${a.hourly.done} of ${a.hourly.goal}`} sub="hours with 250+ steps, 9 AM to 6 PM" />
        <Tile icon={<Dumbbell size={18} />} label="Exercise days" value={`${a.exerciseDays.done} of ${a.exerciseDays.goal}`} sub="this week" />
      </div>
    </section>
  );
}

export function HourlyCard({ h }: { h: Health }) {
  const hrs = h.activity.hourly.hours;
  if (hrs.length < 2) return null;
  return (
    <section className="card" aria-labelledby="hourly-title">
      <div className="row between"><h2 id="hourly-title"><Clock size={18} aria-hidden="true" /> Steps by hour</h2><span className="mono strong">{h.activity.hourly.done} of {h.activity.hourly.goal}</span></div>
      <p className="muted small">Aim for 250 steps every hour from 9 AM to 6 PM.</p>
      <Bars data={hrs.map(x => x.steps)} labels={hrs.map((x, i) => (i % 4 === 0 ? x.hour : ''))} goal={250} format={num0} height={120} />
    </section>
  );
}
