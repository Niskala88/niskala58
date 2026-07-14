// Four Pillars (Bazi) — approximate but formula-verified.
// Day pillar: exact, via Julian Day Number (T = 1+mod(JDN-1,10),
// B = 1+mod(JDN+1,12) — the standard sexagenary day formula).
// Year pillar: uses Li Chun (~Feb 4) as the year boundary, the
// convention Bazi uses (not Chinese New Year). Off by a day in some
// years since Li Chun isn't fixed to the 4th exactly.
// Month pillar: uses approximate solar-term month boundaries (each
// within ~1 day of the true date). Hour pillar: exact given the
// stated hour, using the standard day-stem-to-hour-stem formula.
// This is a reflective approximation, not a professional chart —
// say so in the UI.

import { julianDayNumber } from "./javanese";

const STEMS = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"];
const STEM_PINYIN = ["Jia", "Yi", "Bing", "Ding", "Wu", "Ji", "Geng", "Xin", "Ren", "Gui"];
const STEM_ELEMENT = ["wood", "wood", "fire", "fire", "earth", "earth", "metal", "metal", "water", "water"];
const STEM_POLARITY = ["yang", "yin", "yang", "yin", "yang", "yin", "yang", "yin", "yang", "yin"];

const BRANCHES = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"];
const BRANCH_PINYIN = ["Zi", "Chou", "Yin", "Mao", "Chen", "Si", "Wu", "Wei", "Shen", "You", "Xu", "Hai"];
const BRANCH_ANIMAL = ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"];
const BRANCH_ELEMENT = ["water", "earth", "wood", "wood", "earth", "fire", "fire", "earth", "metal", "metal", "earth", "water"];

const ELEMENT_NAME = {
  id: { wood: "Kayu", fire: "Api", earth: "Tanah", metal: "Logam", water: "Air" },
  en: { wood: "Wood", fire: "Fire", earth: "Earth", metal: "Metal", water: "Water" },
};
const ELEMENT_TRAIT = {
  id: {
    wood: "tumbuh, fleksibel, cari arah — energi perintis",
    fire: "menyala, kelihatan, cepat nyebar — energi ekspresif",
    earth: "stabil, nampung, nyambungin — energi penopang",
    metal: "tajam, terstruktur, presisi — energi penegas",
    water: "ngalir, dalam, adaptif — energi perenung",
  },
  en: {
    wood: "growing, flexible, direction-seeking — pioneer energy",
    fire: "burning, visible, quick to spread — expressive energy",
    earth: "stable, containing, connecting — supporting energy",
    metal: "sharp, structured, precise — decisive energy",
    water: "flowing, deep, adaptive — reflective energy",
  },
};

function pillar(stemIndex0, branchIndex0) {
  const s = ((stemIndex0 % 10) + 10) % 10;
  const b = ((branchIndex0 % 12) + 12) % 12;
  return {
    stem: STEMS[s],
    stemPinyin: STEM_PINYIN[s],
    stemElement: STEM_ELEMENT[s],
    stemPolarity: STEM_POLARITY[s],
    branch: BRANCHES[b],
    branchPinyin: BRANCH_PINYIN[b],
    branchAnimal: BRANCH_ANIMAL[b],
    branchElement: BRANCH_ELEMENT[b],
    label: `${STEM_PINYIN[s]} ${BRANCH_PINYIN[b]}`,
    hanzi: `${STEMS[s]}${BRANCHES[b]}`,
  };
}

// Approximate solar-term month boundaries (month, day) -> branch index0 (Yin=2)
const MONTH_BOUNDS = [
  { after: [1, 5], branch: 1 },   // Chou:  Jan 6 – Feb 3
  { after: [2, 3], branch: 2 },   // Yin:   Feb 4 – Mar 5
  { after: [3, 5], branch: 3 },   // Mao:   Mar 6 – Apr 4
  { after: [4, 4], branch: 4 },   // Chen:  Apr 5 – May 5
  { after: [5, 5], branch: 5 },   // Si:    May 6 – Jun 5
  { after: [6, 5], branch: 6 },   // Wu:    Jun 6 – Jul 6
  { after: [7, 6], branch: 7 },   // Wei:   Jul 7 – Aug 7
  { after: [8, 7], branch: 8 },   // Shen:  Aug 8 – Sep 7
  { after: [9, 7], branch: 9 },   // You:   Sep 8 – Oct 7
  { after: [10, 7], branch: 10 }, // Xu:    Oct 8 – Nov 6
  { after: [11, 6], branch: 11 }, // Hai:   Nov 7 – Dec 6
  { after: [12, 6], branch: 0 },  // Zi:    Dec 7 – Jan 5
];

function monthBranchIndex0(date) {
  const m = date.getMonth() + 1;
  const d = date.getDate();
  let branch = 1; // default Chou (covers early Jan before Jan 6 -> handled below)
  if (m === 1 && d < 6) return 0; // Zi carries from prior December
  for (const b of MONTH_BOUNDS) {
    const [bm, bd] = b.after;
    if (m > bm || (m === bm && d > bd)) branch = b.branch;
  }
  return branch;
}

// Yin-month stem base, by year-stem group (year stem index0)
const YIN_BASE_BY_YEARSTEM_MOD5 = {
  0: 2, // Jia/Ji  -> Bing (index0 2)
  1: 4, // Yi/Geng -> Wu   (index0 4)
  2: 6, // Bing/Xin-> Geng (index0 6)
  3: 8, // Ding/Ren-> Ren  (index0 8)
  4: 0, // Wu/Gui  -> Jia  (index0 0)
};

function baziYear(date) {
  const m = date.getMonth() + 1;
  const d = date.getDate();
  const afterLiChun = m > 2 || (m === 2 && d >= 4);
  return afterLiChun ? date.getFullYear() : date.getFullYear() - 1;
}

function yearPillar(date) {
  const y = baziYear(date);
  const stemIndex0 = ((y + 6) % 10 + 10) % 10;
  const branchIndex0 = ((y + 8) % 12 + 12) % 12;
  return pillar(stemIndex0, branchIndex0);
}

function monthPillar(date, yearStemIndex0) {
  const branchIndex0 = monthBranchIndex0(date);
  // distance from Yin (index0=2) going forward through the fixed order
  const YIN_ORDER = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 1]; // Yin..Chou
  const monthIndexFromYin = YIN_ORDER.indexOf(branchIndex0);
  const yinBase = YIN_BASE_BY_YEARSTEM_MOD5[yearStemIndex0 % 5];
  const stemIndex0 = (yinBase + monthIndexFromYin) % 10;
  return pillar(stemIndex0, branchIndex0);
}

function dayPillar(date) {
  const jdn = julianDayNumber(date);
  const stemIndex0 = ((jdn - 1) % 10 + 10) % 10; // T = 1+mod(JDN-1,10), 0-based here
  const branchIndex0 = ((jdn + 1) % 12 + 12) % 12; // B = 1+mod(JDN+1,12), 0-based here
  return pillar(stemIndex0, branchIndex0);
}

function hourPillar(date, hour, minute, dayStemIndex0) {
  // Hours 23:00–23:59 belong to the next day's Zi hour in tradition.
  let branchIndex0;
  if (hour === 23) branchIndex0 = 0;
  else branchIndex0 = Math.floor(((hour + 1) % 24) / 2);
  const stemIndex0 = (dayStemIndex0 * 2 + branchIndex0) % 10;
  return pillar(stemIndex0, branchIndex0);
}

export function computeBazi(birthDate, birthTimeStr) {
  const yp = yearPillar(birthDate);
  const yearStemIndex0 = STEM_PINYIN.indexOf(yp.stemPinyin);
  const mp = monthPillar(birthDate, yearStemIndex0);
  const dp = dayPillar(birthDate);
  const dayStemIndex0 = STEM_PINYIN.indexOf(dp.stemPinyin);

  let hp = null;
  if (birthTimeStr) {
    const [h, m] = birthTimeStr.split(":").map(Number);
    if (!Number.isNaN(h)) hp = hourPillar(birthDate, h, m || 0, dayStemIndex0);
  }

  const pillars = [yp, mp, dp, ...(hp ? [hp] : [])];
  const elementCounts = { wood: 0, fire: 0, earth: 0, metal: 0, water: 0 };
  pillars.forEach((p) => {
    elementCounts[p.stemElement]++;
    elementCounts[p.branchElement]++;
  });

  const sorted = Object.entries(elementCounts).sort((a, b) => b[1] - a[1]);
  const dominant = sorted[0][0];
  const lacking = sorted.filter(([, n]) => n === 0).map(([k]) => k);

  return {
    year: yp,
    month: mp,
    day: dp,
    hour: hp,
    dayMaster: { element: dp.stemElement, polarity: dp.stemPolarity, stem: dp.stemPinyin },
    elementCounts,
    dominant,
    lacking,
    approximate: true,
  };
}

export { ELEMENT_NAME, ELEMENT_TRAIT };

const PRODUCES = { wood: "fire", fire: "earth", earth: "metal", metal: "water", water: "wood" };
const CONTROLS = { wood: "earth", earth: "water", water: "fire", fire: "metal", metal: "wood" };

export function elementRelation(from, to) {
  if (from === to) return "same";
  if (PRODUCES[from] === to) return "produces";
  if (PRODUCES[to] === from) return "produced_by";
  if (CONTROLS[from] === to) return "controls";
  if (CONTROLS[to] === from) return "controlled_by";
  return "neutral";
}
