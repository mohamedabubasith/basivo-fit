import { AuthExpiredError } from '../lib/auth';
import { fetchLatestHr } from './heart';
import type { Device, Health, SleepNight } from './types';

const API = 'https://health.googleapis.com/v4/users/me/';
const DT = API + 'dataTypes/';

export class NoDeviceError extends Error {}
export class PermissionError extends Error {}

/* eslint-disable @typescript-eslint/no-explicit-any */
type J = any;

const time = (iso: string) => new Date(iso).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
const hourLabel = (iso: string) => new Date(iso).toLocaleTimeString(undefined, { hour: 'numeric' });
const dayLabel = (d: { year: number; month: number; day: number }) =>
  new Date(d.year, d.month - 1, d.day).toLocaleDateString(undefined, { weekday: 'short' });
const civ = (d: Date) => ({ date: { year: d.getFullYear(), month: d.getMonth() + 1, day: d.getDate() } });

async function call(token: string, url: string, body?: unknown): Promise<J> {
  const res = await fetch(url, {
    method: body ? 'POST' : 'GET',
    headers: { Authorization: `Bearer ${token}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined
  });
  if (res.status === 401) throw new AuthExpiredError('Your sign-in has expired.');
  if (res.status === 403) throw new PermissionError('Some permissions were not allowed.');
  if (!res.ok) return {};
  return res.json();
}

export async function fetchHealth(token: string): Promise<Health> {
  const now = new Date();
  const midnight = new Date(now); midnight.setHours(0, 0, 0, 0);
  const tomorrow = new Date(midnight); tomorrow.setDate(tomorrow.getDate() + 1);
  const weekAgo = new Date(midnight); weekAgo.setDate(weekAgo.getDate() - 6);
  const today = { range: { start: civ(midnight), end: civ(tomorrow) }, windowSizeDays: 1 };
  const monday = new Date(midnight); monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));

  // Devices first: an account without a Fitbit or Pixel Watch has nothing to show.
  const devRes = await call(token, API + 'pairedDevices');
  const devices: Device[] = (devRes.pairedDevices || []).map((d: J) => ({
    name: d.deviceVersion || d.deviceType || 'Tracker',
    type: d.deviceType || '',
    battery: typeof d.batteryLevel === 'number' ? d.batteryLevel : null,
    batteryStatus: d.batteryStatus || '',
    lastSync: d.lastSyncTime ? time(d.lastSyncTime) : '--'
  }));

  const settled = await Promise.allSettled([
    fetchLatestHr(token),
    call(token, DT + 'heart-rate/dataPoints:rollUp', { range: { startTime: midnight.toISOString(), endTime: now.toISOString() }, windowSize: '3600s' }),
    call(token, DT + 'steps/dataPoints:dailyRollUp', { range: { start: civ(weekAgo), end: civ(tomorrow) }, windowSizeDays: 1 }),
    call(token, DT + 'distance/dataPoints:dailyRollUp', today),
    call(token, DT + 'active-energy-burned/dataPoints:dailyRollUp', today),
    call(token, DT + 'active-zone-minutes/dataPoints:dailyRollUp', today),
    call(token, DT + 'daily-resting-heart-rate/dataPoints?pageSize=7'),
    call(token, DT + 'daily-heart-rate-variability/dataPoints?pageSize=7'),
    call(token, DT + 'daily-oxygen-saturation/dataPoints?pageSize=1'),
    call(token, DT + 'daily-respiratory-rate/dataPoints?pageSize=1'),
    call(token, DT + 'daily-sleep-temperature-derivations/dataPoints?pageSize=1'),
    call(token, DT + 'weight/dataPoints?pageSize=1'),
    call(token, DT + 'sleep/dataPoints:reconcile?pageSize=7'),
    call(token, DT + 'steps/dataPoints:rollUp', { range: { startTime: midnight.toISOString(), endTime: now.toISOString() }, windowSize: '3600s' }),
    call(token, DT + 'total-calories/dataPoints:dailyRollUp', today),
    call(token, DT + 'heart-rate/dataPoints:dailyRollUp', today),
    call(token, DT + 'active-minutes/dataPoints:dailyRollUp', today),
    call(token, DT + 'exercise/dataPoints?pageSize=50'),
    call(token, DT + 'heart-rate/dataPoints:rollUp', { range: { startTime: midnight.toISOString(), endTime: now.toISOString() }, windowSize: '300s' })
  ]);
  const failed = settled.find(s => s.status === 'rejected') as PromiseRejectedResult | undefined;
  if (failed && (failed.reason instanceof AuthExpiredError || failed.reason instanceof PermissionError)) throw failed.reason;
  const [latestHr, hrHourly, stepsWeekR, distance, energy, azmR, resting, hrv, spo2R, respR, tempR, weightR, sleepR, stepsHourR, totalCalR, hrDayR, activeMinR, exerciseR, hr5R] =
    settled.map(s => (s.status === 'fulfilled' ? s.value : {})) as J[];

  const pts = (x: J) => (x.dataPoints || []) as J[];
  const roll = (x: J) => (x.rollupDataPoints || []) as J[];

  const lh = latestHr && (latestHr as J).bpm ? (latestHr as { bpm: number; at: number }) : undefined;
  const hourly = roll(hrHourly).slice().reverse()
    .map(p => ({ hour: hourLabel(p.startTime), avg: Math.round(p.heartRate?.beatsPerMinuteAvg || 0), min: Math.round(p.heartRate?.beatsPerMinuteMin || 0), max: Math.round(p.heartRate?.beatsPerMinuteMax || 0) }))
    .filter(h => h.avg > 0);
  const stepsWeek = roll(stepsWeekR).filter(p => p.civilStartTime?.date).slice().reverse().map(p => ({ date: dayLabel(p.civilStartTime.date), steps: Number(p.steps?.countSum || 0) }));
  const azmRaw = roll(azmR)[0]?.activeZoneMinutes || {};
  const azm = { fatBurn: Number(azmRaw.sumInFatBurnHeartZone || 0), cardio: Number(azmRaw.sumInCardioHeartZone || 0), peak: Number(azmRaw.sumInPeakHeartZone || 0), total: 0 };
  azm.total = azm.fatBurn + 2 * (azm.cardio + azm.peak);

  const sleep: SleepNight[] = ((sleepR.dataPoints || []) as J[]).map(p => p.sleep || p).filter((s: J) => s?.interval?.startTime && s.interval.endTime).map((s: J) => {
    const mins: Record<string, number> = { DEEP: 0, LIGHT: 0, REM: 0, AWAKE: 0 };
    for (const st of s.stages || []) {
      const k = String(st.type || '').toUpperCase();
      if (k in mins) mins[k] += (new Date(st.endTime).getTime() - new Date(st.startTime).getTime()) / 60000;
    }
    const start = new Date(s.interval.startTime), end = new Date(s.interval.endTime);
    // Longest stretch awake in the middle of the night (joins back-to-back AWAKE stages).
    let longestWake: { minutes: number; at: string } | null = null;
    let runStart = 0, runEnd = 0;
    const stages = ((s.stages || []) as J[]).slice().sort((a, b) => +new Date(a.startTime) - +new Date(b.startTime));
    const flush = () => {
      const m = Math.round((runEnd - runStart) / 60000);
      if (runEnd > runStart && runStart > start.getTime() && runEnd < end.getTime() && m >= 10 && (!longestWake || m > longestWake.minutes))
        longestWake = { minutes: m, at: time(new Date(runStart).toISOString()) };
      runStart = runEnd = 0;
    };
    for (const st of stages) {
      const a = +new Date(st.startTime), b = +new Date(st.endTime);
      if (String(st.type).toUpperCase() === 'AWAKE') { if (runEnd && a - runEnd <= 60000) runEnd = b; else { flush(); runStart = a; runEnd = b; } }
      else if (runEnd) flush();
    }
    flush();
    const meta = s.metadata || {};
    const fall = s.summary?.minutesToFallAsleep;
    const asleep = Math.round(mins.DEEP + mins.LIGHT + mins.REM) || Math.round((end.getTime() - start.getTime()) / 60000 - mins.AWAKE);
    return {
      date: end.toLocaleDateString(undefined, { weekday: 'short' }), minutes: asleep,
      deep: Math.round(mins.DEEP), light: Math.round(mins.LIGHT), rem: Math.round(mins.REM), awake: Math.round(mins.AWAKE),
      bedtime: time(s.interval.startTime), wake: time(s.interval.endTime),
      nap: meta.nap === true || (meta.mainSleep === false && meta.nap !== false),
      longestWake, toFallAsleep: fall != null ? Number(fall) : null,
      start: start.getTime(), end: end.getTime(),
      stages: stages.filter((st: J) => ['AWAKE', 'LIGHT', 'DEEP', 'REM'].includes(String(st.type).toUpperCase()))
        .map((st: J) => ({ type: String(st.type).toUpperCase() as 'AWAKE' | 'LIGHT' | 'DEEP' | 'REM', s: +new Date(st.startTime), e: +new Date(st.endTime) })),
      restless: ((s.shortAwakenings || []) as J[]).filter(a => a.startTime && a.endTime).map(a => ({ s: +new Date(a.startTime), e: +new Date(a.endTime) }))
    };
  }).reverse();

  // Hourly activity: hours between 9 AM and 6 PM with at least 250 steps (the Fitbit rule).
  const hourSteps = roll(stepsHourR).filter(p => p.startTime).map(p => ({ d: new Date(p.startTime), steps: Number(p.steps?.countSum || 0) }))
    .sort((a, b) => +a.d - +b.d);
  const dayHours = hourSteps.filter(h => h.d.getHours() >= 9 && h.d.getHours() < 18);
  const hrDay = roll(hrDayR)[0]?.heartRate;
  // Like the Google Health app, the day's range uses smoothed 5-minute averages, not single raw beats.
  const avg5 = roll(hr5R).map(p => Number(p.heartRate?.beatsPerMinuteAvg)).filter(v => v > 0);
  const totalKcalRaw = roll(totalCalR)[0]?.totalCalories?.kcalSum;
  const activeMinRaw = roll(activeMinR)[0]?.activeMinutes?.activeMinutesRollupByActivityLevel as J[] | undefined;
  const exDays = new Set(pts(exerciseR).map(p => p.exercise?.interval?.startTime).filter(Boolean)
    .map((t: string) => new Date(t)).filter((d: Date) => d >= monday).map((d: Date) => d.toDateString()));

  const spo2 = pts(spo2R)[0]?.dailyOxygenSaturation;
  const resp = pts(respR)[0]?.dailyRespiratoryRate;
  const temp = pts(tempR)[0]?.dailySleepTemperatureDerivations;
  const wt = pts(weightR)[0]?.weight;
  const tempC = temp ? Number(temp.nightlyTemperatureCelsius) : NaN;

  const health: Health = {
    live: true,
    updatedAt: time(now.toISOString()),
    stepGoal: 8000,
    devices,
    heart: {
      now: lh ? { bpm: lh.bpm, time: time(new Date(lh.at).toISOString()), at: lh.at } : null,
      hourly,
      resting: pts(resting).filter(p => p.dailyRestingHeartRate?.date).map(p => ({ date: dayLabel(p.dailyRestingHeartRate.date), bpm: Number(p.dailyRestingHeartRate.beatsPerMinute) })).reverse(),
      todayRange: avg5.length ? { min: Math.round(Math.min(...avg5)), max: Math.round(Math.max(...avg5)), avg: Math.round(hrDay?.beatsPerMinuteAvg ?? avg5.reduce((a, b) => a + b, 0) / avg5.length) } : null,
      hrv: pts(hrv).filter(p => p.dailyHeartRateVariability?.date).map(p => ({ date: dayLabel(p.dailyHeartRateVariability.date), ms: Math.round(p.dailyHeartRateVariability.averageHeartRateVariabilityMilliseconds * 10) / 10 })).reverse()
    },
    activity: {
      stepsToday: stepsWeek.length ? stepsWeek[stepsWeek.length - 1].steps : 0,
      stepsWeek,
      distanceKm: Math.round(Number(roll(distance)[0]?.distance?.millimetersSum || 0) / 10000) / 100,
      activeKcal: Math.round(roll(energy)[0]?.activeEnergyBurned?.kcalSum || 0),
      azm,
      totalKcal: totalKcalRaw != null ? Math.round(Number(totalKcalRaw)) : null,
      activeMinutes: activeMinRaw ? activeMinRaw.reduce((a, r) => a + Number(r.activeMinutesSum || 0), 0) : null,
      hourly: { done: dayHours.filter(h => h.steps >= 250).length, goal: 9, hours: hourSteps.map(h => ({ hour: hourLabel(h.d.toISOString()), steps: h.steps })) },
      exerciseDays: { done: exDays.size, goal: 5 }
    },
    sleep,
    vitals: {
      spo2: spo2 ? { avg: spo2.averagePercentage, low: spo2.lowerBoundPercentage, high: spo2.upperBoundPercentage } : null,
      respRate: resp?.breathsPerMinute ?? null,
      skinTempC: Number.isFinite(tempC) ? Math.round(tempC * 10) / 10 : null,
      weightKg: wt ? Math.round(wt.weightGrams / 100) / 10 : null
    }
  };

  const hasData = health.heart.now || hourly.length || stepsWeek.some(d => d.steps > 0) || sleep.length;
  if (!devices.length && !hasData) throw new NoDeviceError('No Fitbit or Pixel Watch is connected to this Google account.');
  return health;
}

export const isNap = (n: SleepNight) => n.nap ?? n.minutes < 180;
export const mainSleep = (s: SleepNight[]) => [...s].reverse().find(n => !isNap(n)) ?? s[s.length - 1];

export function tip(h: Health): string {
  const night = mainSleep(h.sleep);
  const left = Math.max(h.stepGoal - h.activity.stepsToday, 0);
  const parts: string[] = [];
  if (night) parts.push(`You slept ${Math.floor(night.minutes / 60)} h ${night.minutes % 60} min last night.`);
  if (night?.longestWake && night.longestWake.minutes >= 20)
    parts.push(`You were awake for ${night.longestWake.minutes} minutes around ${night.longestWake.at}. If that happens again, get up for a short, low-light stretch, then go back to bed.`);
  parts.push(left > 0 ? `${left.toLocaleString()} more steps reach your goal, about ${Math.max(5, Math.round(left / 110))} minutes of walking.` : 'You reached your step goal today.');
  const low = h.devices.find(d => d.battery !== null && d.battery <= 20);
  if (low) parts.push(`Charge your ${low.name} soon, it is at ${low.battery}%.`);
  return parts.join(' ');
}
