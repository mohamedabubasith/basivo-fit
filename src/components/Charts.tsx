import { useId } from 'react';

export function Sparkline({ data, up, height = 32 }: { data: number[]; up: boolean; height?: number }) {
  const min = Math.min(...data), max = Math.max(...data);
  const pts = data.map((v, i) => `${(i / (data.length - 1)) * 100},${max === min ? 50 : 100 - ((v - min) / (max - min)) * 100}`).join(' ');
  return (
    <svg className="spark" viewBox="0 0 100 100" preserveAspectRatio="none" height={height} aria-hidden="true">
      <polyline points={pts} fill="none" stroke={up ? 'var(--up)' : 'var(--down)'} strokeWidth="2.5" vectorEffect="non-scaling-stroke" strokeLinejoin="round" />
    </svg>
  );
}

interface Line { value: number; label: string; color: string }

export function AreaChart({ data, labels, lines = [], up = true, height = 180, format = (v: number) => v.toFixed(0) }:
  { data: number[]; labels?: string[]; lines?: Line[]; up?: boolean; height?: number; format?: (v: number) => string }) {
  const id = useId();
  const all = [...data, ...lines.map(l => l.value)];
  const min = Math.min(...all), max = Math.max(...all);
  const pad = (max - min) * 0.12 || 1;
  const lo = min - pad, hi = max + pad;
  const W = 320, H = height;
  const x = (i: number) => (i / (data.length - 1)) * W;
  const y = (v: number) => H - ((v - lo) / (hi - lo)) * H;
  const d = data.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const color = up ? 'var(--up)' : 'var(--down)';
  return (
    <figure className="chart">
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img"
        aria-label={`Chart from ${format(data[0])} to ${format(data[data.length - 1])}`}>
        <defs>
          <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.28" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        <path d={`${d} L${W},${H} L0,${H} Z`} fill={`url(#${id})`} className="draw-fade" />
        {lines.map(l => (
          <g key={l.label}>
            <line x1="0" x2={W} y1={y(l.value)} y2={y(l.value)} stroke={l.color} strokeDasharray="5 5" strokeWidth="1.5" />
            <text x={W - 4} y={y(l.value) - 5} textAnchor="end" className="chart-line-label" fill={l.color}>{l.label}</text>
          </g>
        ))}
        <path d={d} fill="none" stroke={color} strokeWidth="2.5" strokeLinejoin="round" pathLength={1} className="draw-line" />
        <circle cx={x(data.length - 1)} cy={y(data[data.length - 1])} r="4" fill={color} />
      </svg>
      {labels && (
        <figcaption className="chart-x" aria-hidden="true">
          <span>{labels[0]}</span><span>{labels[Math.floor(labels.length / 2)]}</span><span>{labels[labels.length - 1]}</span>
        </figcaption>
      )}
    </figure>
  );
}

export function Bars({ data, labels, goal, format = (v: number) => String(v), height = 150 }:
  { data: number[]; labels: string[]; goal?: number; format?: (v: number) => string; height?: number }) {
  const max = Math.max(...data, goal ?? 0) * 1.1;
  return (
    <figure className="bars" style={{ height }} role="img"
      aria-label={labels.map((l, i) => `${l} ${format(data[i])}`).join(', ')}>
      {goal && <div className="bars-goal" style={{ bottom: `${(goal / max) * 100}%` }}><span>Goal {format(goal)}</span></div>}
      {data.map((v, i) => (
        <div key={i} className="bar-col">
          <div className={`bar ${goal && v >= goal ? 'hit' : ''} ${i === data.length - 1 ? 'today' : ''}`} style={{ height: `${(v / max) * 100}%`, animationDelay: `${i * 50}ms` }} />
          <span className="bar-label">{labels[i]}</span>
        </div>
      ))}
    </figure>
  );
}

export function Ring({ value, max, size = 120, stroke = 12, children, color = 'var(--secondary)' }:
  { value: number; max: number; size?: number; stroke?: number; children?: React.ReactNode; color?: string }) {
  const r = (size - stroke) / 2, c = 2 * Math.PI * r;
  const p = Math.min(value / max, 1);
  return (
    <div className="ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} aria-hidden="true">
        <circle cx={size / 2} cy={size / 2} r={r} stroke="var(--track)" strokeWidth={stroke} fill="none" />
        <circle cx={size / 2} cy={size / 2} r={r} stroke={color} strokeWidth={stroke} fill="none"
          strokeDasharray={c} strokeDashoffset={c * (1 - p)} strokeLinecap="round"
          transform={`rotate(-90 ${size / 2} ${size / 2})`} className="ring-progress" />
      </svg>
      <div className="ring-center">{children}</div>
    </div>
  );
}

// Hourly heart rate: average line with a shaded min-to-max band.
export function RangeChart({ points, height = 170 }: { points: { label: string; avg: number; min: number; max: number }[]; height?: number }) {
  const id = useId();
  if (points.length < 2) return <p className="muted small">Not enough readings yet today.</p>;
  const lo = Math.min(...points.map(p => p.min)) - 5, hi = Math.max(...points.map(p => p.max)) + 5;
  const W = 320, H = height;
  const x = (i: number) => (i / (points.length - 1)) * W;
  const y = (v: number) => H - ((v - lo) / (hi - lo)) * H;
  const band = points.map((p, i) => `${i ? 'L' : 'M'}${x(i)},${y(p.max)}`).join(' ') + ' ' +
    points.slice().reverse().map((p, i) => `L${x(points.length - 1 - i)},${y(p.min)}`).join(' ') + ' Z';
  const line = points.map((p, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(p.avg).toFixed(1)}`).join(' ');
  const peak = points.reduce((a, p) => (p.max > a.max ? p : a));
  return (
    <figure className="chart">
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img"
        aria-label={`Heart rate today from ${points[0].label} to ${points[points.length - 1].label}. Highest ${peak.max} bpm around ${peak.label}.`}>
        <defs>
          <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--heart)" stopOpacity="0.35" />
            <stop offset="100%" stopColor="var(--heart)" stopOpacity="0.08" />
          </linearGradient>
        </defs>
        <path d={band} fill={`url(#${id})`} className="draw-fade" />
        <path d={line} fill="none" stroke="var(--heart)" strokeWidth="2.5" strokeLinejoin="round" pathLength={1} className="draw-line" />
        <circle cx={x(points.length - 1)} cy={y(points[points.length - 1].avg)} r="4.5" fill="var(--heart)" className="live-dot" />
      </svg>
      <figcaption className="chart-x" aria-hidden="true">
        <span>{points[0].label}</span><span>{points[Math.floor(points.length / 2)].label}</span><span>{points[points.length - 1].label}</span>
      </figcaption>
    </figure>
  );
}
