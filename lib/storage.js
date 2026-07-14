// Thin storage layer. Swap these five functions for Postgres/Neon
// calls later without touching any component.

const DREAMS_KEY = "niskala.dreams.v1";
const PULLS_KEY = "niskala.pulls.v1";

function read(key) {
  if (typeof window === "undefined") return [];
  try {
    return JSON.parse(window.localStorage.getItem(key) || "[]");
  } catch {
    return [];
  }
}

function write(key, value) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(key, JSON.stringify(value));
}

export function listDreams() {
  return read(DREAMS_KEY).sort((a, b) => b.createdAt - a.createdAt);
}

export function getDream(id) {
  return read(DREAMS_KEY).find((d) => d.id === id) || null;
}

export function saveDream({ text, mood, symbols }) {
  const dreams = read(DREAMS_KEY);
  const dream = {
    id: `d${Date.now()}`,
    text,
    mood: mood || "",
    symbols: symbols || [],
    interpretations: null,
    createdAt: Date.now(),
  };
  dreams.push(dream);
  write(DREAMS_KEY, dreams);
  return dream;
}

export function updateDream(id, patch) {
  const dreams = read(DREAMS_KEY);
  const i = dreams.findIndex((d) => d.id === id);
  if (i === -1) return null;
  dreams[i] = { ...dreams[i], ...patch };
  write(DREAMS_KEY, dreams);
  return dreams[i];
}

export function listPulls() {
  return read(PULLS_KEY).sort((a, b) => b.createdAt - a.createdAt);
}

export function savePull(pull) {
  const pulls = read(PULLS_KEY);
  pulls.push({ ...pull, createdAt: Date.now() });
  write(PULLS_KEY, pulls);
}

export function todayPull() {
  const today = new Date().toDateString();
  return read(PULLS_KEY).find(
    (p) => new Date(p.createdAt).toDateString() === today
  );
}
