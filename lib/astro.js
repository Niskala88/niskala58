// Personal layer: sun sign, shio, and the daily petung match
// between birth weton and today's weton.

import { getWeton } from "./javanese";
import { getPlanetaryHour } from "./planetary";
import { computeBazi, elementRelation, ELEMENT_NAME } from "./bazi";

const SIGNS = [
  { name: "Capricorn", from: [12, 22], element: "earth" },
  { name: "Aquarius", from: [1, 20], element: "air" },
  { name: "Pisces", from: [2, 19], element: "water" },
  { name: "Aries", from: [3, 21], element: "fire" },
  { name: "Taurus", from: [4, 20], element: "earth" },
  { name: "Gemini", from: [5, 21], element: "air" },
  { name: "Cancer", from: [6, 21], element: "water" },
  { name: "Leo", from: [7, 23], element: "fire" },
  { name: "Virgo", from: [8, 23], element: "earth" },
  { name: "Libra", from: [9, 23], element: "air" },
  { name: "Scorpio", from: [10, 23], element: "water" },
  { name: "Sagittarius", from: [11, 22], element: "fire" },
];

export function sunSign(date) {
  const md = (date.getMonth() + 1) * 100 + date.getDate();
  const ordered = SIGNS.filter((s) => s.name !== "Capricorn")
    .map((s) => ({ ...s, start: s.from[0] * 100 + s.from[1] }))
    .sort((a, b) => a.start - b.start);
  let match = SIGNS[0];
  for (const s of ordered) if (md >= s.start) match = s;
  if (md >= 1222) match = SIGNS[0];
  return match;
}

const SHIO = [
  "Monyet", "Ayam", "Anjing", "Babi", "Tikus", "Kerbau",
  "Macan", "Kelinci", "Naga", "Ular", "Kuda", "Kambing",
];

export function shio(date) {
  const year = date.getFullYear();
  const name = SHIO[year % 12];
  const boundary = date.getMonth() === 0 || (date.getMonth() === 1 && date.getDate() < 5);
  return { name, approximate: boundary };
}

const DAY_MEANING = {
  id: {
    Minggu: "matahari — visibilitas, energi yang ingin dilihat",
    Senin: "bulan — kepekaan, urusan rumah dan hati",
    Selasa: "api — dorongan, ketegasan, kadang tergesa",
    Rabu: "merkurial — bicara, pesan, transaksi kecil",
    Kamis: "guru/jupiter — perluasan, belajar, restu",
    Jumat: "venus — hubungan, keindahan, kesepakatan",
    Sabtu: "saturnus — batas, kedisiplinan, pekerjaan berat",
  },
  en: {
    Minggu: "sun — visibility, wanting to be seen",
    Senin: "moon — sensitivity, home and heart matters",
    Selasa: "fire — drive, sharpness, sometimes too fast",
    Rabu: "mercurial — talk, messages, small transactions",
    Kamis: "jupiter — expansion, learning, blessing",
    Jumat: "venus — relationships, beauty, agreements",
    Sabtu: "saturn — limits, discipline, heavy work",
  },
};

// Pancasuda: the birth neptu's permanent character reading —
// distinct from petungToday, which matches birth neptu against
// TODAY's neptu. This one never changes.
const PANCASUDA = [
  { key: "Sri", tone: "open",
    meaning: { id: "pembawa rezeki — orang mudah dekat sama kamu, dan kamu sering jadi sandaran tanpa diminta.",
      en: "fortune-bringer — people gravitate to you easily, and you end up being someone's support without asking for the role." } },
  { key: "Lungguh", tone: "open",
    meaning: { id: "berwibawa — kamu cocok mimpin, dan dihormati bahkan waktu nggak lagi nyari itu.",
      en: "authority — you're built to lead, and get respected even when you're not chasing it." } },
  { key: "Gedhong", tone: "open",
    meaning: { id: "penyimpan — kamu jago ngelola dan nabung, baik itu duit maupun rahasia orang.",
      en: "the vault — you're good at managing and saving, whether that's money or other people's secrets." } },
  { key: "Lara", tone: "guard",
    meaning: { id: "penuh uji — hidupmu sering ditempa lewat gesekan. Bukan kutukan, tapi juga bukan alasan buat terus-terusan nahan yang emang udah nggak sehat.",
      en: "tested — your life gets shaped through friction more than most. Not a curse, but also not a reason to keep tolerating what's genuinely unhealthy." } },
  { key: "Pati", tone: "close",
    meaning: { id: "penutup siklus — kamu sering jadi orang yang nyelesain apa yang orang lain tinggalin setengah jalan.",
      en: "the closer — you're often the one who finishes what other people leave half-done." } },
];

export function pancasudaBirth(birthNeptu) {
  return PANCASUDA[birthNeptu % 5];
}

const PETUNG = [
  { key: "Pati", tone: "close",
    meaning: { id: "penutupan — hari buat nyelesain, bukan mulai.", en: "closing — a day to finish things, not start them." } },
  { key: "Sri", tone: "open",
    meaning: { id: "rezeki ngalir — hari bagus buat mulai dan nawarin sesuatu.", en: "fortune flows — a good day to start something or make an offer." } },
  { key: "Lungguh", tone: "open",
    meaning: { id: "wibawa — hari bagus buat tampil, rapat, negosiasi.", en: "authority — a good day to show up, meet, negotiate." } },
  { key: "Dunya", tone: "open",
    meaning: { id: "keberuntungan materi — hari bagus buat transaksi.", en: "material luck — a good day for transactions." } },
  { key: "Lara", tone: "guard",
    meaning: { id: "gesekan — jaga energi, hindari konfrontasi.", en: "friction — guard your energy, avoid confrontation." } },
];

export function petungToday(birthNeptu, todayNeptu) {
  const r = (birthNeptu + todayNeptu) % 5;
  return PETUNG[r];
}

export function personalReading(birthDate, birthTimeStr, now = new Date()) {
  const birthWeton = getWeton(birthDate);
  const today = getWeton(now);
  const sign = sunSign(birthDate);
  const zodiacShio = shio(birthDate);

  let birthHour = null;
  if (birthTimeStr) {
    const [h, m] = birthTimeStr.split(":").map(Number);
    if (!Number.isNaN(h)) {
      const bd = new Date(birthDate);
      bd.setHours(h, m || 0);
      birthHour = getPlanetaryHour(bd);
    }
  }

  const petung = petungToday(birthWeton.neptu, today.neptu);
  const isWetonDay =
    birthWeton.day === today.day && birthWeton.pasaran === today.pasaran;
  const pancasuda = pancasudaBirth(birthWeton.neptu);

  let bazi = null;
  let baziToday = null;
  let dayMasterRelationToday = null;
  try {
    bazi = computeBazi(birthDate, birthTimeStr);
    baziToday = computeBazi(now, null);
    dayMasterRelationToday = elementRelation(
      baziToday.day.stemElement,
      bazi.dayMaster.element
    );
  } catch {
    bazi = null;
  }

  return {
    birthWeton, today, sign, shio: zodiacShio, birthHour, petung, isWetonDay,
    pancasuda, bazi, baziToday, dayMasterRelationToday,
  };
}

export { DAY_MEANING };

export function dosAndDonts(reading, moon, hour, lang = "id") {
  const dos = [];
  const donts = [];
  const { petung, isWetonDay, sign, birthWeton, today } = reading;
  const t = (id, en) => (lang === "en" ? en : id);

  if (isWetonDay) {
    dos.push(t(
      "Hari wetonmu, selapanan — tradisinya: puasa, laku prihatin, atau sekadar melambat.",
      "Your weton day — tradition says: fast, sit still, or just slow down."
    ));
    donts.push(t("Jangan jejalin hal berat hari ini kalau bisa dihindari.", "Don't cram in anything heavy today if you can help it."));
  }

  const pm = petung.meaning[lang === "en" ? "en" : "id"];
  if (petung.tone === "open") {
    dos.push(`${t("Petung", "Today's petung is")} ${petung.key}: ${pm}`);
  } else if (petung.tone === "guard") {
    donts.push(`${t("Petung", "Today's petung is")} ${petung.key}: ${pm}`);
    dos.push(t("Prioritaskan istirahat dan urusan ringan.", "Prioritize rest and light matters."));
  } else {
    donts.push(`${t("Petung", "Today's petung is")} ${petung.key}: ${pm}`);
    dos.push(t("Tutup urusan yang menggantung — hari bagus buat beres-beres.", "Close out loose ends — good day for tidying up."));
  }

  if (moon.fraction <= 0.5) {
    dos.push(t("Bulan lagi tumbuh — tanam, mulai, kirim.", "Moon's waxing — plant, start, send."));
  } else {
    dos.push(t("Bulan lagi susut — lepasin, rapiin, selesaiin.", "Moon's waning — release, tidy, finish."));
    donts.push(t("Jangan luncurin hal besar deket bulan mati.", "Don't launch anything big this close to the new moon."));
  }

  const fireDays = ["Mars", "Sun"];
  if (fireDays.includes(hour.dayRuler) && sign.element === "fire") {
    dos.push(t(
      `Hari ${hour.dayRuler} nyambung sama elemen apimu (${sign.name}) — pakai buat yang butuh nyali.`,
      `${hour.dayRuler}'s day lines up with your fire sign (${sign.name}) — use it for the thing that takes nerve.`
    ));
  }
  if (hour.dayRuler === "Moon" && sign.element === "water") {
    dos.push(t(
      `Hari Bulan nyambung sama elemen airmu (${sign.name}) — obrolan jujur bakal ngalir sendiri.`,
      `Moon's day lines up with your water sign (${sign.name}) — honest conversation flows easier.`
    ));
  }

  if (today.isKliwon) {
    dos.push(t("Kliwon: catat sinkronisitas dan mimpi, lalu lintas isyarat lagi ramai.", "Kliwon: log your synchronicities and dreams — the signal traffic is heavier today."));
  }

  if (birthWeton.pasaran === today.pasaran && !isWetonDay) {
    dos.push(t(
      `Pasaran hari ini sama kayak pasaran lahirmu (${today.pasaran}) — hari yang akrab, intuisi lebih tajam.`,
      `Today's market-day matches your birth market-day (${today.pasaran}) — a familiar day, sharper intuition.`
    ));
  }

  if (reading.dayMasterRelationToday && reading.bazi) {
    const dm = ELEMENT_NAME[lang === "en" ? "en" : "id"][reading.bazi.dayMaster.element];
    const rel = reading.dayMasterRelationToday;
    if (rel === "produces")
      dos.push(t(`Elemen hari ini nyalain day master-mu (${dm}) — energi ngalir keluar gampang, bagus buat berkarya.`,
        `Today's element feeds your day master (${dm}) — energy flows out easily, good for making things.`));
    else if (rel === "produced_by")
      dos.push(t(`Hari ini "ngasih makan" day master-mu (${dm}) — waktu yang pas buat nerima, belajar, isi ulang.`,
        `Today "feeds" your day master (${dm}) — a good time to receive, learn, recharge.`));
    else if (rel === "controls")
      donts.push(t(`Elemen hari ini nekan day master-mu (${dm}) — kurangi ambisi besar, jaga energi.`,
        `Today's element presses on your day master (${dm}) — dial back big ambitions, guard your energy.`));
    else if (rel === "controlled_by")
      dos.push(t(`Day master-mu (${dm}) lagi unggul atas elemen hari ini — momentum di tanganmu, ambil inisiatif.`,
        `Your day master (${dm}) has the upper hand today — momentum is yours, take initiative.`));
    else if (rel === "same")
      dos.push(t(`Elemen hari ini sewarna sama day master-mu (${dm}) — keputusan bakal kerasa lebih jelas.`,
        `Today's element matches your day master (${dm}) — decisions will feel clearer.`));
  }

  return { dos: dos.slice(0, 5), donts: donts.slice(0, 4) };
}
