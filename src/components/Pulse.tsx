import { Heart } from 'lucide-react';

// A heart that beats at the given rate, plus a scrolling heartbeat line.
export function BeatingHeart({ bpm, size = 28 }: { bpm: number; size?: number }) {
  const dur = bpm > 0 ? 60 / bpm : 1;
  return (
    <span className="beat" style={{ ['--beat' as string]: `${dur}s`, width: size, height: size }} aria-hidden="true">
      <Heart size={size} fill="currentColor" strokeWidth={0} />
    </span>
  );
}

export function EcgLine({ bpm }: { bpm: number }) {
  const dur = bpm > 0 ? (60 / bpm) * 2 : 2;
  const beat = 'l14 0 l4 -6 l4 6 l6 0 l3 6 l5 -34 l5 40 l4 -12 l5 0 l8 -5 l8 5 l16 0';
  const d = `M0 30 ${beat} ${beat} ${beat} ${beat} l40 0`;
  return (
    <svg className="ecg" viewBox="0 0 320 60" preserveAspectRatio="none" aria-hidden="true" style={{ ['--ecg' as string]: `${dur}s` }}>
      <path d={d} className="ecg-path" />
    </svg>
  );
}
