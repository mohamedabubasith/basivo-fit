import { useState } from 'react';
import { ChevronLeft, ChevronRight, Info } from 'lucide-react';
import type { Health, SleepNight } from '../data/types';
import { isNap } from '../data/health';

type Stage = 'AWAKE' | 'LIGHT' | 'DEEP' | 'REM';
const W = 340, LANE = 26, GAP = 34, TOP = 18;
const lanes: { key: Stage | 'RESTLESS'; label: string; color: string }[] = [
  { key: 'AWAKE', label: 'Awake', color: 'var(--s-awake)' },
  { key: 'RESTLESS', label: 'Restlessness', color: 'var(--s-restless)' },
  { key: 'REM', label: 'REM', color: 'var(--s-rem)' },
  { key: 'LIGHT', label: 'Light', color: 'var(--s-light)' },
  { key: 'DEEP', label: 'Deep', color: 'var(--s-deep)' }
];
const laneY = (k: string) => TOP + lanes.findIndex(l => l.key === k) * (LANE + GAP);
const t = (ms: number) => new Date(ms).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
const dur = (min: number) => { const h = Math.floor(min / 60), m = Math.round(min % 60); return h ? `${h}h ${m}m` : `${m} min`; };
const mins = (a: { s: number; e: number }[]) => a.reduce((x, r) => x + (r.e - r.s) / 60000, 0);

// Simple, open rules from the sleep stages (not Google's private formula).
export function quality(n: SleepNight) {
  const st = (n.stages ?? []).slice().sort((a, b) => a.s - b.s);
  const firstSound = st.find(x => x.type === 'DEEP' || x.type === 'REM');
  const toSound = firstSound && n.start ? Math.round((firstSound.s - n.start) / 60000) : null;
  const sound = mins(st.filter(x => x.type === 'DEEP' || x.type === 'REM'));
  const soundPct = n.minutes ? (sound / n.minutes) * 100 : 0;
  const restless = Math.round(mins(n.restless ?? []));
  const breaks = st.filter(x => x.type === 'AWAKE' && (x.e - x.s) / 60000 >= 5 && x.s > (n.start ?? 0) && x.e < (n.end ?? Infinity));
  const breakMin = Math.round(mins(breaks));
  return [
    { label: 'Time to deep or REM sleep', value: toSound == null ? '--' : dur(toSound), status: toSound == null ? 'none' : toSound <= 30 ? 'ok' : 'high', pos: Math.min((toSound ?? 0) / 90, 1), band: [0, 30 / 90], why: 'How long after going to bed you first reached deep or REM sleep. Under 30 minutes is typical.' },
    { label: 'Deep + REM sleep', value: `${dur(sound)} (${Math.round(soundPct)}%)`, status: soundPct >= 35 ? 'ok' : 'low', pos: Math.min(soundPct / 70, 1), band: [35 / 70, 55 / 70], why: 'The restoring part of sleep. Adults usually spend 35 to 55% of sleep in deep and REM.' },
    { label: 'Restlessness', value: dur(restless), status: restless <= 15 ? 'ok' : 'high', pos: Math.min(restless / 60, 1), band: [0, 15 / 60], why: 'Short wake-ups and tossing that you probably do not remember. Under 15 minutes is typical.' },
    { label: 'Interruptions', value: `${dur(breakMin)}, ${breaks.length} ${breaks.length === 1 ? 'time' : 'times'}`, status: breakMin <= 10 ? 'ok' : 'high', pos: Math.min(breakMin / 60, 1), band: [0, 10 / 60], why: 'Times you were awake for 5 minutes or more in the middle of the night. Under 10 minutes in total is typical.' }
  ] as const;
}

function Hypnogram({ n }: { n: SleepNight }) {
  const start = n.start!, end = n.end!;
  const x = (ms: number) => ((ms - start) / (end - start)) * W;
  const st = (n.stages ?? []).slice().sort((a, b) => a.s - b.s);
  const restless = (n.restless ?? []).filter(r => r.s >= start && r.e <= end);
  const of = (k: Stage) => mins(st.filter(p => p.type === k));
  const totals: Record<string, number> = { AWAKE: of('AWAKE'), REM: of('REM'), LIGHT: of('LIGHT'), DEEP: of('DEEP'), RESTLESS: mins(restless) };
  const H = TOP + lanes.length * (LANE + GAP) - GAP + 4;
  return (
    <figure className="hyp">
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img"
        aria-label={`Sleep from ${t(start)} to ${t(end)}. ${lanes.map(l => `${l.label} ${dur(totals[l.key])}`).join(', ')}.`}>
        {lanes.map(l => (
          <g key={l.key}>
            <text x="0" y={laneY(l.key) - 8} className="hyp-label">{l.label} <tspan className="hyp-val">· {dur(totals[l.key])}</tspan></text>
            <rect x="0" y={laneY(l.key)} width={W} height={LANE} rx={LANE / 2} className="hyp-track" />
          </g>
        ))}
        {/* thin lines joining one stage to the next */}
        {st.slice(1).map((cur, i) => {
          const prev = st[i];
          const a = laneY(prev.type) + LANE / 2, b = laneY(cur.type) + LANE / 2;
          return <line key={`c${i}`} x1={x(cur.s)} x2={x(cur.s)} y1={Math.min(a, b)} y2={Math.max(a, b)} className="hyp-join" />;
        })}
        {st.map((p, i) => {
          const l = lanes.find(z => z.key === p.type)!;
          const w = Math.max(x(p.e) - x(p.s), 2.5);
          return <rect key={i} x={x(p.s)} y={laneY(p.type)} width={w} height={LANE} rx={Math.min(8, w / 2)} fill={l.color} className="hyp-block" style={{ animationDelay: `${i * 12}ms` }} />;
        })}
        {restless.map((r, i) => <rect key={`r${i}`} x={x(r.s)} y={laneY('RESTLESS') + 4} width={Math.max(x(r.e) - x(r.s), 2.5)} height={LANE - 8} rx="1.5" fill="var(--s-restless)" className="hyp-block" />)}
      </svg>
      <figcaption className="hyp-x">
        <div><span className="mono">{t(start)}</span><span className="muted tiny">Went to bed</span></div>
        <div className="center"><span className="mono">{t(start + (end - start) / 2)}</span></div>
        <div className="right"><span className="mono">{t(end)}</span><span className="muted tiny">Out of bed</span></div>
      </figcaption>
    </figure>
  );
}

function Quality({ n }: { n: SleepNight }) {
  const tag = { ok: ['In range', 'ok'], high: ['Above range', 'warn'], low: ['Below range', 'warn'], none: ['No data', 'none'] } as const;
  return (
    <section className="card" aria-labelledby="sq-title">
      <h2 id="sq-title">Sleep quality</h2>
      <ul className="sq">
        {quality(n).map(q => (
          <li key={q.label}>
            <div className="row between"><p className="small"><b>{q.label}</b> <span className="muted">· {q.value}</span></p><span className={`sq-tag ${tag[q.status][1]}`}>{tag[q.status][0]}</span></div>
            <div className="sq-track">
              <span className="sq-band" style={{ left: `${q.band[0] * 100}%`, width: `${(q.band[1] - q.band[0]) * 100}%` }} />
              <span className={`sq-fill ${tag[q.status][1]}`} style={{ width: `${q.pos * 100}%` }} />
              <span className="sq-knob" style={{ left: `${q.pos * 100}%` }} />
            </div>
            <p className="muted tiny">{q.why}</p>
          </li>
        ))}
      </ul>
      <p className="muted tiny"><Info size={12} aria-hidden="true" className="inline-icon" /> The dashed box is the typical range. These are simple, open rules worked out from your sleep stages. Google's own sleep score uses a private formula that it does not share.</p>
    </section>
  );
}

export default function SleepDetail({ h }: { h: Health }) {
  const nights = h.sleep.filter(n => !isNap(n) && n.start && n.stages?.length);
  const [i, setI] = useState(nights.length - 1);
  const n = nights[Math.min(Math.max(i, 0), nights.length - 1)];
  if (!n) return null;
  const date = new Date(n.end!).toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'short' });
  return (
    <>
      <section className="card">
        <div className="row between">
          <div><h2>{i === nights.length - 1 ? 'Last night' : date}</h2><p className="muted small">{dur(n.minutes)} asleep · {dur((n.end! - n.start!) / 60000)} in bed</p></div>
          <div className="row gap">
            <button className="icon-btn" aria-label="Earlier night" disabled={i <= 0} onClick={() => setI(v => v - 1)}><ChevronLeft size={20} /></button>
            <button className="icon-btn" aria-label="Later night" disabled={i >= nights.length - 1} onClick={() => setI(v => v + 1)}><ChevronRight size={20} /></button>
          </div>
        </div>
        <Hypnogram n={n} />
      </section>
      <Quality n={n} />
    </>
  );
}
