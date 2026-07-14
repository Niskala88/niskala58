// Planetary hours, Chaldean order.
// Uses fixed 06:00–18:00 day arc — near the equator (Indonesia)
// sunrise/sunset barely move, so this is honest, not lazy.

const CHALDEAN = ["Saturn", "Jupiter", "Mars", "Sun", "Venus", "Mercury", "Moon"];
// Day ruler by weekday, Sunday first:
const DAY_RULER = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];

const FLAVOR = {
  Sun: "vitality, visibility, asking for what you want",
  Moon: "intuition, home matters, emotional honesty",
  Mars: "cutting, courage, workouts, hard conversations",
  Mercury: "messages, contracts, ideas, quick errands",
  Jupiter: "growth, generosity, big-picture planning",
  Venus: "beauty, connection, pleasure, making things lovely",
  Saturn: "boundaries, endings, slow patient work",
};

export function getPlanetaryHour(date = new Date()) {
  const ruler = DAY_RULER[date.getDay()];
  const startIdx = CHALDEAN.indexOf(ruler);
  const h = date.getHours() + date.getMinutes() / 60;
  // Hours 0..23 mapped from 06:00 start of the planetary day
  const sinceSix = (h - 6 + 24) % 24;
  const hourIndex = Math.floor(sinceSix); // each planetary hour ~= 1 clock hour here
  const planet = CHALDEAN[(startIdx + hourIndex) % 7];
  const nextPlanet = CHALDEAN[(startIdx + hourIndex + 1) % 7];
  return {
    dayRuler: ruler,
    current: planet,
    next: nextPlanet,
    flavor: FLAVOR[planet],
    nextFlavor: FLAVOR[nextPlanet],
  };
}
