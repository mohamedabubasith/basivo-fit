import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { ChevronLeft, ChevronRight, RotateCcw } from 'lucide-react';
import { getSession } from '../lib/auth';
import { useHealth } from '../lib/store';
import { DEFAULT_LIMITS, fetchHeartDay, fetchHeartWeek, fmtDur, zoneLabel, zoneOf, ZONES, type HeartDay, type HeartWeek, type Zone, type ZoneLimits } from '../data/heart';
import { Skeleton } from './ui';

const W = 340, H = 230, PAD_R = 34;
const zoneColor: Record<Zone, string> = { LIGHT: 'var(--z-light)', MODERATE: 'var(--z-moderate)', VIGOROUS: 'var(--z-vigorous)', PEAK: 'var(--z-peak)' };
const time = (t: number) => new Date(t).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });

function scaleY(l: ZoneLimits, max: number) {
  const lo = 30, hi = Math.max(l.peak + 16, max + 10);
  return { lo, hi, y: (v: number) => H - ((v - lo) / (hi - lo)) * H };
}

function ZoneLines({ l, y }: { l: ZoneLimits; y: (v: number) => number }) {
  const rows: [number, Zone][] = [[l.peak, 'PEAK'], [l.vigorous, 'VIGOROUS'], [l.moderate, 'MODERATE']];
  return <>{rows.map(([v, z]) => (
    <g key={z}>
      <line x1="0" x2={W - PAD_R - 4} y1={y(v)} y2={y(v)} stroke={zoneColor[z]} strokeWidth="2" strokeDasharray="1.5 7" strokeLinecap="round" />
      <text x={W - 2} y={y(v) + 4} textAnchor="end" className="hr-axis">{v}</text>
    </g>
  ))}<text x={W - 2} y={H - 2} textAnchor="end" className="hr-axis">30</text></>;
}

function DayChart({ d }: { d: HeartDay }) {
  const id = useId().replace(/:/g, '');
  const [scrub, setScrub] = useState<number | null>(null);
  const svg = useRef<SVGSVGElement>(null);
  const { y } = scaleY(d.limits, d.max ?? 0);
  const plotW = W - PAD_R;
  const x = (t: number) => ((t - d.start) / (d.end - d.start)) * plotW;
  // Break the line where the tracker was off for more than 15 minutes.
  const path = useMemo(() => d.points.map((p, i) => `${i && p.t - d.points[i - 1].t <= 15 * 60000 ? 'L' : 'M'}${x(p.t).toFixed(1)},${y(p.avg).toFixed(1)}`).join(' '), [d]);
  const bands: [Zone, number, number][] = [
    ['LIGHT', y(d.limits.moderate), H], ['MODERATE', y(d.limits.vigorous), y(d.limits.moderate)],
    ['VIGOROUS', y(d.limits.peak), y(d.limits.vigorous)], ['PEAK', -20, y(d.limits.peak)]
  ];
  const onMove = (e: React.PointerEvent) => {
    if (!svg.current || !d.points.length) return;
    const r = svg.current.getBoundingClientRect();
    const t = d.start + ((e.clientX - r.left) / r.width) * (W / plotW) * (d.end - d.start);
    let best = 0;
    for (let i = 1; i < d.points.length; i++) if (Math.abs(d.points[i].t - t) < Math.abs(d.points[best].t - t)) best = i;
    setScrub(best);
  };
  const sp = scrub !== null ? d.points[scrub] : null;
  const ticks = [0, 6, 12, 18].map(h => d.start + h * 3600000);
  return (
    <figure className="hr-chart">
      <p className="hr-scrub mono small" aria-live="polite">{sp ? `${time(sp.t)} · ${Math.round(sp.avg)} bpm (${Math.round(sp.min)} to ${Math.round(sp.max)})` : 'Touch the chart to see each reading'}</p>
      <svg ref={svg} viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img"
        aria-label={`Heart rate from ${d.min} to ${d.max} bpm`}
        onPointerDown={onMove} onPointerMove={e => (e.buttons || e.pointerType === 'mouse') && onMove(e)} onPointerLeave={() => setScrub(null)}>
        <defs>{bands.map(([z, top, bottom]) => <clipPath key={z} id={`${id}${z}`}><rect x="0" y={top} width={W} height={Math.max(0, bottom - top)} /></clipPath>)}</defs>
        <ZoneLines l={d.limits} y={y} />
        {bands.map(([z]) => <path key={z} d={path} clipPath={`url(#${id}${z})`} fill="none" stroke={zoneColor[z]} strokeWidth="2" strokeLinejoin="round" className="draw-line" pathLength={1} />)}
        {sp && <g><line x1={x(sp.t)} x2={x(sp.t)} y1="0" y2={H} stroke="var(--muted-fg)" strokeWidth="1" /><circle cx={x(sp.t)} cy={y(sp.avg)} r="5" fill={zoneColor[zoneOf(sp.avg, d.limits)]} stroke="var(--card)" strokeWidth="2" /></g>}
      </svg>
      <figcaption className="hr-x" style={{ width: `${(plotW / W) * 100}%` }}>{ticks.map(t => <span key={t}>{new Date(t).toLocaleTimeString(undefined, { hour: 'numeric' })}</span>)}</figcaption>
    </figure>
  );
}

function WeekChart({ w }: { w: HeartWeek }) {
  const max = Math.max(0, ...w.days.map(d => d.max));
  const { y } = scaleY(w.limits, max);
  const plotW = W - PAD_R, step = plotW / Math.max(w.days.length, 1);
  return (
    <figure className="hr-chart">
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" aria-label={w.days.map(d => `${d.label} ${d.min} to ${d.max} bpm`).join(', ')}>
        <ZoneLines l={w.limits} y={y} />
        {w.days.map((d, i) => {
          const cx = step * i + step / 2;
          return <g key={d.date} className="hr-week-bar" style={{ animationDelay: `${i * 50}ms` }}>
            <line x1={cx} x2={cx} y1={y(d.max)} y2={y(d.min)} stroke="var(--z-light)" strokeWidth="10" strokeLinecap="round" />
            <circle cx={cx} cy={y(d.avg)} r="3" fill="var(--card)" />
          </g>;
        })}
      </svg>
      <figcaption className="hr-x" style={{ width: `${(plotW / W) * 100}%` }}>{w.days.map(d => <span key={d.date}>{d.label}</span>)}</figcaption>
    </figure>
  );
}

function ZoneList({ secs }: { secs: Record<Zone, number> }) {
  const total = Object.values(secs).reduce((a, b) => a + b, 0) || 1;
  return (
    <section className="card" aria-labelledby="zones-title">
      <h2 id="zones-title">Time in heart-rate zones</h2>
      <p className="muted small">Zones are set from your fitness and age.</p>
      <ul className="hr-zones">
        {ZONES.map(z => {
          const pct = Math.round((secs[z] / total) * 100);
          return <li key={z}>
            <p className="small"><b>{zoneLabel[z]}</b> <span className="muted">· {pct}% · {fmtDur(secs[z])}</span></p>
            <span className="zone-track big"><span className="zone-fill" style={{ width: `${Math.max(secs[z] ? 1.5 : 0, (secs[z] / total) * 100)}%`, background: zoneColor[z] }} /></span>
          </li>;
        })}
      </ul>
    </section>
  );
}

export default function HeartDetail() {
  const { demo, session } = useHealth();
  const [mode, setMode] = useState<'D' | 'W'>('D');
  const [offset, setOffset] = useState(0);
  const [day, setDay] = useState<HeartDay | null>(null);
  const [week, setWeek] = useState<HeartWeek | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let alive = true;
    setFailed(false);
    if (demo) { mode === 'D' ? setDay(demoDay(offset)) : setWeek(demoWeek()); return; }
    const s = getSession();
    if (!s) return;
    const load = () => (mode === 'D' ? fetchHeartDay(s.token, offset).then(r => alive && setDay(r)) : fetchHeartWeek(s.token).then(r => alive && setWeek(r))).catch(() => alive && setFailed(true));
    if (mode === 'D') setDay(null); else setWeek(null);
    load();
    // Today keeps updating while the screen is open.
    const id = mode === 'D' && offset === 0 ? setInterval(load, 30_000) : undefined;
    return () => { alive = false; if (id) clearInterval(id); };
  }, [mode, offset, demo, session]);

  const label = mode === 'W' ? 'Last 7 days' : offset === 0 ? 'Today' : offset === 1 ? 'Yesterday'
    : new Date(Date.now() - offset * 86400000).toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'short' });
  const data = mode === 'D' ? day : week;
  const lo = mode === 'D' ? day?.min : week && week.days.length ? Math.min(...week.days.map(d => d.min)) : null;
  const hi = mode === 'D' ? day?.max : week && week.days.length ? Math.max(...week.days.map(d => d.max)) : null;
  const limits = (mode === 'D' ? day?.limits : week?.limits) ?? DEFAULT_LIMITS;

  return (
    <>
      <div className="segmented two" role="tablist" aria-label="Range">
        {(['D', 'W'] as const).map(m => <button key={m} role="tab" aria-selected={mode === m} className={`seg ${mode === m ? 'on' : ''}`} onClick={() => { setMode(m); setOffset(0); }}>{m === 'D' ? 'Day' : 'Week'}</button>)}
      </div>
      <section className="card hr-card">
        <div className="row between">
          <h2>{label}</h2>
          {mode === 'D' && <div className="row gap">
            <button className="icon-btn" aria-label="Previous day" onClick={() => setOffset(o => o + 1)}><ChevronLeft size={20} /></button>
            <button className="icon-btn" aria-label="Next day" disabled={offset === 0} onClick={() => setOffset(o => Math.max(0, o - 1))}><ChevronRight size={20} /></button>
            <button className="icon-btn" aria-label="Back to today" disabled={offset === 0} onClick={() => setOffset(0)}><RotateCcw size={18} /></button>
          </div>}
        </div>
        {!data && !failed && <Skeleton h={300} />}
        {failed && <p className="muted">Could not load heart rate. Pull down or try again later.</p>}
        {data && (lo == null || hi == null ? <p className="muted">No heart rate recorded for this {mode === 'D' ? 'day' : 'week'}.</p> : <>
          <p className="hr-range"><span className="mono">{lo}–{hi}</span> <span className="unit">bpm</span></p>
          <p className="muted small">High of {hi} bpm in the {zoneLabel[zoneOf(hi, limits)].toLowerCase()} zone</p>
          {mode === 'D' && day ? <DayChart d={day} /> : week && <WeekChart w={week} />}
          <ul className="hr-legend">{(['LIGHT', 'MODERATE', 'VIGOROUS', 'PEAK'] as Zone[]).map(z => <li key={z}><span className="hr-dots" style={{ color: zoneColor[z] }} aria-hidden="true">•••</span>{zoneLabel[z]}</li>)}</ul>
        </>)}
      </section>
      {data && <ZoneList secs={data.zoneSeconds} />}
    </>
  );
}

// Demo data shaped like a real day.
function demoDay(offset: number): HeartDay {
  const start = new Date(); start.setHours(0, 0, 0, 0); start.setDate(start.getDate() - offset);
  const end = new Date(start); end.setDate(end.getDate() + 1);
  const stop = offset === 0 ? Date.now() : end.getTime();
  const points = [];
  for (let t = start.getTime(); t < stop; t += 300000) {
    const h = (t - start.getTime()) / 3600000;
    const base = h < 7 ? 62 : h < 11 ? 66 : h < 12.5 ? 98 : h < 18 ? 84 : 76;
    const v = base + Math.sin(t / 900000) * 4 + ((t / 300000) % 7) - 3 + (Math.abs(h - 11.6) < 0.15 ? 24 : 0);
    points.push({ t, avg: v, min: v - 5, max: v + 6 });
  }
  return { start: start.getTime(), end: end.getTime(), points, limits: DEFAULT_LIMITS, min: 57, max: 122, avg: 74, zoneSeconds: { LIGHT: 81660, MODERATE: 1020, VIGOROUS: 0, PEAK: 0 } };
}
function demoWeek(): HeartWeek {
  const days = [0, 1, 2, 3, 4, 5, 6].map(i => { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - 6 + i); return { label: d.toLocaleDateString(undefined, { weekday: 'short' }), date: d.getTime(), min: 54 + (i % 3), max: 112 + ((i * 7) % 25), avg: 72 + (i % 4) }; });
  return { days, limits: DEFAULT_LIMITS, zoneSeconds: { LIGHT: 560000, MODERATE: 6200, VIGOROUS: 900, PEAK: 0 } };
}
