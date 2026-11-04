import { useEffect, useState } from 'react';

export type ThemePref = 'system' | 'light' | 'dark';
const KEY = 'pulsefolio.theme';
const media = () => window.matchMedia('(prefers-color-scheme: dark)');
const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

export const getPref = (): ThemePref => {
  try { return (localStorage.getItem(KEY) as ThemePref) || 'system'; } catch { return 'system'; }
};
const resolve = (p: ThemePref) => (p === 'system' ? (media().matches ? 'dark' : 'light') : p);

function apply(p: ThemePref) {
  const t = resolve(p);
  document.documentElement.dataset.theme = t;
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', t === 'dark' ? '#0B1220' : '#F6F8FC');
}

export function initTheme() {
  apply(getPref());
  media().addEventListener('change', () => { if (getPref() === 'system') apply('system'); });
}

// Switches theme with a circle that grows from the tapped button.
export function setTheme(p: ThemePref, origin?: { x: number; y: number }) {
  try { localStorage.setItem(KEY, p); } catch { /* storage blocked */ }
  window.dispatchEvent(new CustomEvent('pulsefolio-theme', { detail: p }));
  const doc = document as Document & { startViewTransition?: (cb: () => void) => { ready: Promise<void> } };
  if (!doc.startViewTransition || reducedMotion() || resolve(p) === document.documentElement.dataset.theme) { apply(p); return; }
  const x = origin?.x ?? innerWidth / 2, y = origin?.y ?? 0;
  const r = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
  const t = doc.startViewTransition(() => apply(p));
  t.ready.then(() => {
    document.documentElement.animate(
      { clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${r}px at ${x}px ${y}px)`] },
      { duration: 550, easing: 'cubic-bezier(0.2, 0, 0, 1)', pseudoElement: '::view-transition-new(root)' }
    );
  });
}

export function useTheme() {
  const [pref, setPref] = useState<ThemePref>(getPref());
  const [resolved, setResolved] = useState(resolve(getPref()));
  useEffect(() => {
    const on = () => { setPref(getPref()); setResolved(resolve(getPref())); };
    window.addEventListener('pulsefolio-theme', on);
    media().addEventListener('change', on);
    return () => { window.removeEventListener('pulsefolio-theme', on); media().removeEventListener('change', on); };
  }, []);
  return { pref, resolved };
}
