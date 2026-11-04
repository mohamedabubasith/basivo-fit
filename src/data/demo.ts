import type { Health } from './types';

const day = (back: number) => { const d = new Date(); d.setDate(d.getDate() - back); return d.toLocaleDateString(undefined, { weekday: 'short' }); };
const hourNames = Array.from({ length: 17 }, (_, i) => new Date(2000, 0, 1, i).toLocaleTimeString(undefined, { hour: 'numeric' }));
const avgs = [73, 63, 68, 67, 61, 64, 61, 63, 60, 65, 65, 68, 88, 94, 97, 91, 86];

export const demoHealth: Health = {
  live: false,
  updatedAt: 'demo',
  stepGoal: 8000,
  devices: [{ name: 'Fitbit Air', type: 'TRACKER', battery: 62, batteryStatus: 'Medium', lastSync: '4:51 PM' }],
  heart: {
    now: { bpm: 78, time: '4:50 PM' },
    hourly: hourNames.map((hour, i) => ({ hour, avg: avgs[i], min: avgs[i] - 9, max: avgs[i] + 22 })),
    resting: [66, 65, 68, 64, 63, 65, 65].map((bpm, i) => ({ date: day(6 - i), bpm })),
    todayRange: { min: 57, max: 122, avg: 74 },
    hrv: [28.1, 27.4, 25.9, 26.8, 27.2, 26.3, 26.5].map((ms, i) => ({ date: day(6 - i), ms }))
  },
  activity: {
    stepsToday: 6240,
    stepsWeek: [7420, 9310, 5120, 8860, 10240, 6630, 6240].map((steps, i) => ({ date: day(6 - i), steps })),
    distanceKm: 4.6,
    azm: { fatBurn: 17, cardio: 6, peak: 0, total: 29 },
    totalKcal: 1353,
    activeKcal: 310,
    activeMinutes: 94,
    hourly: { done: 1, goal: 9, hours: [0, 0, 0, 0, 0, 0, 40, 180, 86, 203, 380, 182, 8, 83, 151, 42, 68].map((steps, i) => ({ hour: hourNames[i], steps })) },
    exerciseDays: { done: 0, goal: 5 }
  },
  sleep: [
    [412, 72, 238, 84, 18, '11:20 PM', '6:12 AM'], [365, 58, 214, 70, 23, '12:05 AM', '6:30 AM'],
    [448, 88, 252, 92, 16, '10:55 PM', '6:40 AM'], [391, 66, 229, 78, 18, '11:40 PM', '6:21 AM'],
    [430, 80, 244, 88, 18, '11:10 PM', '6:35 AM'], [342, 49, 205, 61, 27, '12:30 AM', '6:22 AM'],
    [416, 70, 232, 60, 54, '11:41 PM', '9:09 AM']
  ].map(([minutes, deep, light, rem, awake, bedtime, wake], i) => ({
    date: day(6 - i), minutes: minutes as number, deep: deep as number, light: light as number,
    rem: rem as number, awake: awake as number, bedtime: bedtime as string, wake: wake as string,
    longestWake: i === 6 ? { minutes: 54, at: '2:30 AM' } : null
  })),
  vitals: { spo2: { avg: 96.3, low: 95, high: 97.7 }, respRate: 14.4, skinTempC: 33.8, weightKg: 68 }
};
