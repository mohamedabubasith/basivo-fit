import { AuthExpiredError } from '../lib/auth';

const DT = 'https://health.googleapis.com/v4/users/me/dataTypes/';
/* eslint-disable @typescript-eslint/no-explicit-any */
type J = any;

export type Zone = 'LIGHT' | 'MODERATE' | 'VIGOROUS' | 'PEAK';
export const ZONES: Zone[] = ['PEAK', 'VIGOROUS', 'MODERATE', 'LIGHT'];
export const zoneLabel: Record<Zone, string> = { LIGHT: 'Light', MODERATE: 'Moderate', VIGOROUS: 'Vigorous', PEAK: 'Peak' };
export interface ZoneLimits { moderate: number; vigorous: number; peak: number }
export const DEFAULT_LIMITS: ZoneLimits = { moderate: 116, vigorous: 142, peak: 174 };

export interface HrPoint { t: number; avg: number; min: number; max: number }
export interface HeartDay {
  start: number; end: number;
  points: HrPoint[];
  min: number | null; max: number | null; avg: number | null;
  limits: ZoneLimits;
  zoneSeconds: Record<Zone, number>;
}
export interface HeartWeekDay { label: string; date: number; min: number; max: number; avg: number }
export interface HeartWeek { days: HeartWeekDay[]; zoneSeconds: Record<Zone, number>; limits: ZoneLimits }

async function post(token: string, url: string, body: unknown): Promise<J> {
  const res = await fetch(url, { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  if (res.status === 401) throw new AuthExpiredError('Your sign-in has expired.');
  if (!res.ok) return {};
  return res.json();
}
async function get(token: string, url: string): Promise<J> {
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (res.status === 401) throw new AuthExpiredError('Your sign-in has expired.');
  if (!res.ok) return {};
  return res.json();
}

// Rollups can come back in pages; follow up to 6 of them.
async function rollAll(token: string, url: string, body: J): Promise<J[]> {
  const out: J[] = [];
  let pageToken: string | undefined;
  for (let i = 0; i < 6; i++) {
    const r = await post(token, url, pageToken ? { ...body, pageToken } : body);
    out.push(...(r.rollupDataPoints || []));
    pageToken = r.nextPageToken;
    if (!pageToken) break;
  }
  return out;
}

const civ = (d: Date) => ({ date: { year: d.getFullYear(), month: d.getMonth() + 1, day: d.getDate() } });
const emptyZones = (): Record<Zone, number> => ({ LIGHT: 0, MODERATE: 0, VIGOROUS: 0, PEAK: 0 });

function addZones(target: Record<Zone, number>, p: J) {
  for (const z of p?.timeInHeartRateZone?.timeInHeartRateZones || []) {
    const k = String(z.heartRateZone).toUpperCase() as Zone;
    if (k in target) target[k] += parseFloat(String(z.duration || '0')) || 0;
  }
}

async function limits(token: string): Promise<ZoneLimits> {
  const r = await get(token, DT + 'daily-heart-rate-zones/dataPoints?pageSize=1');
  const zs: J[] = r.dataPoints?.[0]?.dailyHeartRateZones?.heartRateZones || [];
  const min = (t: string) => Number(zs.find(z => z.heartRateZoneType === t)?.minBeatsPerMinute);
  const l = { moderate: min('MODERATE'), vigorous: min('VIGOROUS'), peak: min('PEAK') };
  return Number.isFinite(l.moderate) && Number.isFinite(l.vigorous) && Number.isFinite(l.peak) ? l : DEFAULT_LIMITS;
}

export function dayStart(offset: number) {
  const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - offset); return d;
}

// One day of heart rate in 5-minute steps, plus time in each zone.
export async function fetchHeartDay(token: string, offset: number): Promise<HeartDay> {
  const start = dayStart(offset);
  const next = new Date(start); next.setDate(next.getDate() + 1);
  const end = offset === 0 ? new Date() : next;
  const [raw, zonesR, lim] = await Promise.all([
    rollAll(token, DT + 'heart-rate/dataPoints:rollUp', { range: { startTime: start.toISOString(), endTime: end.toISOString() }, windowSize: '300s' }),
    post(token, DT + 'time-in-heart-rate-zone/dataPoints:dailyRollUp', { range: { start: civ(start), end: civ(next) }, windowSizeDays: 1 }),
    limits(token)
  ]);
  const points = raw.filter(p => p.heartRate?.beatsPerMinuteAvg).map(p => ({
    t: new Date(p.startTime).getTime(), avg: p.heartRate.beatsPerMinuteAvg, min: p.heartRate.beatsPerMinuteMin, max: p.heartRate.beatsPerMinuteMax
  })).sort((a, b) => a.t - b.t);
  const zoneSeconds = emptyZones();
  addZones(zoneSeconds, zonesR.rollupDataPoints?.[0]);
  return {
    start: start.getTime(), end: next.getTime(), points, limits: lim, zoneSeconds,
    min: points.length ? Math.min(...points.map(p => p.min)) : null,
    max: points.length ? Math.max(...points.map(p => p.max)) : null,
    avg: points.length ? Math.round(points.reduce((a, p) => a + p.avg, 0) / points.length) : null
  };
}

// The last 7 days as daily lowest-to-highest ranges.
export async function fetchHeartWeek(token: string): Promise<HeartWeek> {
  const start = dayStart(6), tomorrow = dayStart(-1);
  const body = { range: { start: civ(start), end: civ(tomorrow) }, windowSizeDays: 1 };
  const [hr, zones, lim] = await Promise.all([
    post(token, DT + 'heart-rate/dataPoints:dailyRollUp', body),
    post(token, DT + 'time-in-heart-rate-zone/dataPoints:dailyRollUp', body),
    limits(token)
  ]);
  const days = ((hr.rollupDataPoints || []) as J[]).filter(p => p.civilStartTime?.date && p.heartRate?.beatsPerMinuteAvg).map(p => {
    const d = p.civilStartTime.date; const date = new Date(d.year, d.month - 1, d.day);
    return { label: date.toLocaleDateString(undefined, { weekday: 'short' }), date: date.getTime(), min: Math.round(p.heartRate.beatsPerMinuteMin), max: Math.round(p.heartRate.beatsPerMinuteMax), avg: Math.round(p.heartRate.beatsPerMinuteAvg) };
  }).sort((a, b) => a.date - b.date);
  const zoneSeconds = emptyZones();
  for (const p of zones.rollupDataPoints || []) addZones(zoneSeconds, p);
  return { days, zoneSeconds, limits: lim };
}

// Newest heart rate: 1-minute windows over the last 20 minutes, newest wins.
export async function fetchLatestHr(token: string): Promise<{ bpm: number; at: number } | null> {
  const now = Date.now();
  const r = await post(token, DT + 'heart-rate/dataPoints:rollUp', { range: { startTime: new Date(now - 20 * 60000).toISOString(), endTime: new Date(now).toISOString() }, windowSize: '60s' });
  const pts = ((r.rollupDataPoints || []) as J[]).filter(p => p.heartRate?.beatsPerMinuteAvg).sort((a, b) => +new Date(b.endTime) - +new Date(a.endTime));
  if (!pts.length) return null;
  return { bpm: Math.round(pts[0].heartRate.beatsPerMinuteAvg), at: new Date(pts[0].endTime).getTime() };
}

export const zoneOf = (bpm: number, l: ZoneLimits): Zone => (bpm >= l.peak ? 'PEAK' : bpm >= l.vigorous ? 'VIGOROUS' : bpm >= l.moderate ? 'MODERATE' : 'LIGHT');
export const fmtDur = (s: number) => { const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60); return h ? `${h}h ${m}m` : `${m} min`; };
