// Javanese weton: 7-day week x 5-day pasaran cycle.
// Pasaran derived from Julian Day Number mod 5.
// Verified anchor: 17 Aug 1945 = Jumat Legi.

const PASARAN = ["Legi", "Pahing", "Pon", "Wage", "Kliwon"];
const PASARAN_NEPTU = { Legi: 5, Pahing: 9, Pon: 7, Wage: 4, Kliwon: 8 };

const DAYS = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
const DAY_NEPTU = {
  Minggu: 5, Senin: 4, Selasa: 3, Rabu: 7, Kamis: 8, Jumat: 6, Sabtu: 9,
};

const PASARAN_MEANING = {
  Legi: "sweet beginnings, openness, east wind",
  Pahing: "intensity, ambition, holding fire",
  Pon: "visibility, expression, standing in light",
  Wage: "stillness, guardedness, deep roots",
  Kliwon: "the threshold day, spirit traffic, heightened intuition",
};

export function julianDayNumber(date) {
  const y = date.getFullYear();
  const m = date.getMonth() + 1;
  const d = date.getDate();
  const a = Math.floor((14 - m) / 12);
  const yy = y + 4800 - a;
  const mm = m + 12 * a - 3;
  return (
    d +
    Math.floor((153 * mm + 2) / 5) +
    365 * yy +
    Math.floor(yy / 4) -
    Math.floor(yy / 100) +
    Math.floor(yy / 400) -
    32045
  );
}

export function getWeton(date = new Date()) {
  const jdn = julianDayNumber(date);
  const pasaran = PASARAN[jdn % 5];
  const day = DAYS[date.getDay()];
  const neptu = DAY_NEPTU[day] + PASARAN_NEPTU[pasaran];
  return {
    day,
    pasaran,
    label: `${day} ${pasaran}`,
    neptu,
    meaning: PASARAN_MEANING[pasaran],
    isKliwon: pasaran === "Kliwon",
  };
}
