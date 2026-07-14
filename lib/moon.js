// Moon phase from synodic month approximation.
// Anchor new moon: 2000-01-06 18:14 UTC.

const SYNODIC = 29.53058867;
const ANCHOR = Date.UTC(2000, 0, 6, 18, 14) / 86400000; // days

const PHASES = [
  { max: 0.033, name: "New moon", icon: "new", note: "seed intentions, keep them private" },
  { max: 0.216, name: "Waxing crescent", icon: "waxing", note: "gather, tend, small consistent moves" },
  { max: 0.283, name: "First quarter", icon: "waxing", note: "friction is information — push through" },
  { max: 0.466, name: "Waxing gibbous", icon: "waxing", note: "refine and adjust before the reveal" },
  { max: 0.533, name: "Full moon", icon: "full", note: "peak charge — celebrate, release, don't decide" },
  { max: 0.716, name: "Waning gibbous", icon: "waning", note: "share, teach, distribute what ripened" },
  { max: 0.783, name: "Last quarter", icon: "waning", note: "cut what's done, forgive the rest" },
  { max: 0.966, name: "Waning crescent", icon: "waning", note: "rest, compost, dream deeply" },
  { max: 1.01, name: "New moon", icon: "new", note: "seed intentions, keep them private" },
];

export function getMoon(date = new Date()) {
  const now = date.getTime() / 86400000;
  const age = ((now - ANCHOR) % SYNODIC + SYNODIC) % SYNODIC;
  const frac = age / SYNODIC;
  const phase = PHASES.find((p) => frac <= p.max) || PHASES[0];
  const illumination = Math.round(
    ((1 - Math.cos(2 * Math.PI * frac)) / 2) * 100
  );
  return {
    ageDays: Math.round(age * 10) / 10,
    fraction: frac,
    illumination,
    name: phase.name,
    icon: phase.icon,
    note: phase.note,
    isWaning: frac > 0.533 && frac <= 0.966,
  };
}
