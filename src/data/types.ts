export interface SleepNight {
  date: string;
  minutes: number;
  deep: number;
  light: number;
  rem: number;
  awake: number;
  bedtime: string;
  wake: string;
}

export interface HeartHour { hour: string; avg: number; min: number; max: number }
export interface Device { name: string; type: string; battery: number | null; batteryStatus: string; lastSync: string }

export interface Health {
  live: boolean;
  updatedAt: string;
  stepGoal: number;
  devices: Device[];
  heart: {
    now: { bpm: number; time: string } | null;
    hourly: HeartHour[];
    resting: { date: string; bpm: number }[];
    hrv: { date: string; ms: number }[];
  };
  activity: {
    stepsToday: number;
    stepsWeek: { date: string; steps: number }[];
    distanceKm: number;
    activeKcal: number;
    azm: { fatBurn: number; cardio: number; peak: number; total: number };
  };
  sleep: SleepNight[];
  vitals: { spo2: { avg: number; low: number; high: number } | null; respRate: number | null; skinTempC: number | null; weightKg: number | null };
}
