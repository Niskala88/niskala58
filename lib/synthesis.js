// Synthesis layer — turns computed signals (weton, bazi, moon,
// planetary hour) into readable text. Two entry points:
// 1. narrativeDailySynthesis — three short, jargon-free sections
//    for the home screen.
// 2. lifeAreaReading — a birth-chart-only read split into
//    love/career/health, deliberately blunt.
// Both take a `lang` param ("id" | "en").

import { ELEMENT_NAME, ELEMENT_TRAIT, elementRelation } from "./bazi";
import { DAY_MEANING } from "./astro";
import { getPlanetaryHour } from "./planetary";

function moonCategory(moon) {
  if (moon.fraction <= 0.05 || moon.fraction >= 0.97) return "new";
  if (moon.fraction < 0.48) return "waxing";
  if (moon.fraction <= 0.55) return "full";
  return "waning";
}

const MOON_TONE = {
  new: { id: "Bulan mati — apa pun yang kamu mulai sekarang, biarin diam-diam dulu.", en: "New moon — whatever you start now, let it stay quiet for a while." },
  waxing: { id: "Bulan lagi naik — ini fasenya bangun, bukan beresin.", en: "Waxing moon — this is a building phase, not a wrap-up phase." },
  full: { id: "Purnama — emosi dan hasil kerja sama-sama di puncak. Rayain atau lepasin, tapi jangan mutusin hal besar hari ini.", en: "Full moon — feelings and results both peak. Celebrate or release, but don't decide anything big today." },
  waning: { id: "Bulan lagi turun — waktunya ngelepas dan beresin, bukan mulai lagi.", en: "Waning moon — time to let go and tidy, not start over." },
};

// ---- Foundation: driven mainly by weton (gap between birth neptu and
// today's neptu, plus the actual pasaran meeting), moon as accent. ----
const FOUNDATION = {
  wetonDay: (ctx) => ({
    id: `Hari ini wetonmu muter balik — ${ctx.birthWeton} ketemu ${ctx.birthWeton} lagi, pas 35 hari sekali. Badan dan kepalamu udah tau duluan sebelum kamu sadar. Jangan isi hari ini sama hal baru, ini buat ngitung ulang, bukan mulai.`,
    en: `Your weton has looped back today — ${ctx.birthWeton} meeting ${ctx.birthWeton} again, once every 35 days. Your body knows before your head does. Don't fill today with new things. This one's for recalculating, not starting.`,
  }),
  same: (ctx) => ({
    id: `Neptu hari ini (${ctx.todayNeptu}) sama persis kayak neptu lahirmu — meski wetonnya beda (${ctx.birthWeton} ketemu ${ctx.todayWeton}), bobotnya kerasa akrab, kayak ketemu versi lain dirimu sendiri.`,
    en: `Today's neptu (${ctx.todayNeptu}) matches your birth neptu exactly — even though the weton itself differs (${ctx.birthWeton} meeting ${ctx.todayWeton}), the weight feels familiar, like running into another version of yourself.`,
  }),
  veryFar: (ctx) => ({
    id: `${ctx.todayWeton} (neptu ${ctx.todayNeptu}) ketemu weton lahirmu ${ctx.birthWeton} (neptu ${ctx.birthWeton_neptu}) — selisih ${ctx.gap} poin, salah satu jarak terjauh dari ritme normalmu bulan ini. Kalau hal kecil kerasa berat hari ini, itu bukan cuma perasaanmu.`,
    en: `${ctx.todayWeton} (neptu ${ctx.todayNeptu}) meets your birth weton ${ctx.birthWeton} (neptu ${ctx.birthWeton_neptu}) — a ${ctx.gap}-point gap, one of the widest from your normal rhythm this month. If small things feel heavy today, that's not just in your head.`,
  }),
  far: (ctx) => ({
    id: `${ctx.todayWeton} ketemu weton lahirmu ${ctx.birthWeton} — selisih neptu ${ctx.gap} poin bikin hari ini kerasa agak di luar jalur biasa. Nggak buruk, cuma nggak otomatis nyaman.`,
    en: `${ctx.todayWeton} meets your birth weton ${ctx.birthWeton} — a ${ctx.gap}-point neptu gap makes today feel a bit off your usual track. Not bad, just not automatically comfortable.`,
  }),
  near: (ctx) => ({
    id: `${ctx.todayWeton} ketemu weton lahirmu ${ctx.birthWeton} — selisih neptu cuma ${ctx.gap} poin, masih deket sama ritme normalmu, dengan gesekan kecil yang justru sehat.`,
    en: `${ctx.todayWeton} meets your birth weton ${ctx.birthWeton} — only a ${ctx.gap}-point neptu gap, still close to your normal rhythm, with a bit of healthy friction.`,
  }),
  veryNear: (ctx) => ({
    id: `${ctx.todayWeton} deket banget sama weton lahirmu ${ctx.birthWeton} — selisih neptu ${ctx.gap} poin doang. Hari ini kerasa hampir kayak default settingmu sendiri.`,
    en: `${ctx.todayWeton} sits very close to your birth weton ${ctx.birthWeton} — just a ${ctx.gap}-point neptu gap. Today feels almost like your default setting.`,
  }),
};

// ---- Growth: driven mainly by petung (weton-based daily fortune),
// with the bazi day-master relation woven in as a secondary accent. ----
const GROWTH_TEXT = {
  open: (ctx) => ({
    id: `Petung hari ini ${ctx.petungKey}: ${ctx.petungMeaning} Ini datangnya dari pertemuan wetonmu — ${ctx.birthWeton} ketemu ${ctx.todayWeton}.${ctx.baziClause}`,
    en: `Today's petung is ${ctx.petungKey}: ${ctx.petungMeaning} That comes from your weton meeting today's — ${ctx.birthWeton} meeting ${ctx.todayWeton}.${ctx.baziClauseEn}`,
  }),
  guard: (ctx) => ({
    id: `Petung hari ini ${ctx.petungKey}: ${ctx.petungMeaning} Godaan terbesarmu adalah maksain sesuatu yang harusnya ditunda — tahan, dan biarin ini lewat.${ctx.baziClause}`,
    en: `Today's petung is ${ctx.petungKey}: ${ctx.petungMeaning} Your biggest temptation is pushing something that should wait — resist, and let this one pass.${ctx.baziClauseEn}`,
  }),
  close: (ctx) => ({
    id: `Petung hari ini ${ctx.petungKey}: ${ctx.petungMeaning} Ada satu urusan yang udah kelamaan gantung — hari ini pas buat nutupnya, bukan buat nambah yang baru.${ctx.baziClause}`,
    en: `Today's petung is ${ctx.petungKey}: ${ctx.petungMeaning} Something's been hanging around too long — today's for closing it out, not adding anything new.${ctx.baziClauseEn}`,
  }),
};

// ---- Connection: driven mainly by the weton day's traditional
// meaning, with the planetary day-ruler woven in as a secondary accent. ----
const CONNECTION = {
  base: (ctx) => ({
    id: `${ctx.day} bawa watak ${ctx.dayMeaning}, dan itu warnain gimana kamu keliatan hari ini. ${ctx.planetClause} Ditambah watak dasarmu (${ctx.pancasudaKey}) — ${ctx.pancasudaFlavor}`,
    en: `${ctx.day} carries the character of ${ctx.dayMeaning}, and that colors how you come across today. ${ctx.planetClauseEn} On top of that, your baseline temperament (${ctx.pancasudaKey}) — ${ctx.pancasudaFlavorEn}`,
  }),
};

const PANCASUDA_FLAVOR = {
  Sri: { id: "orang gampang percaya sama kamu duluan hari ini, manfaatin buat nembus obrolan yang biasanya susah.", en: "people tend to trust you first today — use that to break into a conversation that's usually hard." },
  Lungguh: { id: "kata-katamu kedengeran lebih berbobot dari biasa hari ini, tapi jangan sampai kedengeran menggurui.", en: "your words carry more weight than usual today — just watch that it doesn't tip into lecturing." },
  Gedhong: { id: "kamu bakal lebih pengen nyimpen daripada berbagi hari ini — sah aja, nggak semua harus dibuka sekarang.", en: "you'll lean toward holding things back rather than sharing today — that's fine, not everything needs opening up right now." },
  Lara: { id: "kesabaranmu bakal diuji dikit lewat orang lain hari ini — pilih kapan worth-nya ngeladenin.", en: "your patience will get tested a bit through other people today — pick your battles on what's worth engaging." },
  Pati: { id: "kamu bakal ketemu momen buat nutup obrolan atau hubungan yang emang udah waktunya — nggak usah dipaksa lanjut.", en: "you'll run into a moment to close out a conversation or connection that's run its course — no need to force it further." },
};

const PLANET_ACTIVITY = {
  Sun: { id: "tampil dan minta apa yang kamu mau", en: "showing up and asking for what you want" },
  Moon: { id: "ngobrol jujur soal perasaan atau urusan rumah", en: "honest talk about feelings or home matters" },
  Mars: { id: "eksekusi hal yang butuh nyali atau olahraga berat", en: "executing something that takes nerve, or a hard workout" },
  Mercury: { id: "kirim pesan penting, tanda tangan, atau nego kecil", en: "sending an important message, signing something, or a small negotiation" },
  Jupiter: { id: "ngajuin hal besar atau mulai belajar sesuatu", en: "pitching something big or starting to learn something" },
  Venus: { id: "hal yang berhubungan sama koneksi, keindahan, kesepakatan", en: "anything about connection, beauty, or agreements" },
  Saturn: { id: "kerja fokus yang butuh disiplin, atau beresin utang lama", en: "focused disciplined work, or clearing an old debt" },
};

function findBestHour(now, targetPlanets) {
  // Prefer waking hours (06:00–22:00) first, only fall back to
  // overnight hours if nothing in that window matches.
  for (let h = 6; h <= 22; h++) {
    const d = new Date(now);
    d.setHours(h, 0, 0, 0);
    const p = getPlanetaryHour(d).current;
    if (targetPlanets.includes(p)) return { hour: h, planet: p };
  }
  for (let h = 0; h < 24; h++) {
    const d = new Date(now);
    d.setHours(h, 0, 0, 0);
    const p = getPlanetaryHour(d).current;
    if (targetPlanets.includes(p)) return { hour: h, planet: p };
  }
  return null;
}

// ---- Energy: moon illumination + neptu gap direction + bazi element,
// framed as embodied/physical guidance. ----
function energySection(ctx, moon, bazi, lang) {
  const l = lang === "en" ? "en" : "id";
  const risingMoon = moon.fraction <= 0.5;
  const moonLine = l === "en"
    ? `The moon is ${moon.illumination}% lit and ${risingMoon ? "still filling out" : "already past its peak"} — your physical energy today likely follows that same curve: ${risingMoon ? "building steadily rather than arriving all at once" : "better spent early than forced late"}.`
    : `Bulan lagi ${moon.illumination}% keliatan dan ${risingMoon ? "masih ngisi" : "udah lewat puncaknya"} — energi fisikmu hari ini kemungkinan ngikutin kurva yang sama: ${risingMoon ? "numpuk pelan-pelan, bukan langsung penuh" : "lebih baik dipakai di awal daripada dipaksa di akhir"}.`;

  const dmLine = bazi
    ? (l === "en"
        ? ` Your core wiring runs on ${ELEMENT_NAME.en[bazi.dayMaster.element]} (${ELEMENT_TRAIT.en[bazi.dayMaster.element]}), so when today feels off, that's usually the part of you asking for attention first.`
        : ` Wataknmu jalan di elemen ${ELEMENT_NAME.id[bazi.dayMaster.element]} (${ELEMENT_TRAIT.id[bazi.dayMaster.element]}), jadi kalau hari ini kerasa nggak pas, biasanya itu bagian dirimu yang minta diperhatiin duluan.`)
    : "";

  const gapLine = l === "en"
    ? ` With today sitting ${ctx.gap} points from your birth number, expect your usual stamina to run ${ctx.gap <= 2 ? "close to normal" : ctx.gap <= 5 ? "slightly off, nothing dramatic" : "noticeably different from a typical day"} — plan accordingly instead of assuming today is a baseline day.`
    : ` Karena hari ini berjarak ${ctx.gap} poin dari angka lahirmu, staminamu kemungkinan ${ctx.gap <= 2 ? "deket normal" : ctx.gap <= 5 ? "agak beda dikit, nggak drastis" : "kerasa beda banget dari hari biasa"} — rencanain sesuai itu, jangan anggap hari ini hari standar.`;

  return moonLine + dmLine + gapLine;
}

// ---- Decisions: petung tone + a real scan of today's planetary
// hours to recommend a specific window. ----
function decisionsSection(ctx, petung, hour, now, lang) {
  const l = lang === "en" ? "en" : "id";
  const activityMap = {
    open: ["Mercury", "Venus", "Jupiter", "Sun"],
    guard: ["Moon", "Saturn"],
    close: ["Saturn", "Moon"],
  };
  const targets = activityMap[petung.tone] || ["Mercury"];
  const best = findBestHour(now, targets);

  const baseLine = {
    open: { id: "Petung hari ini kebuka, jadi ini hari yang aman buat maju.", en: "Today's petung is open, so it's safe to move forward." },
    guard: { id: "Petung hari ini nge-rem, jadi hindari keputusan besar sampai keadaannya lebih jelas.", en: "Today's petung is holding back, so avoid big decisions until things are clearer." },
    close: { id: "Petung hari ini ke arah nutup, jadi fokus nyelesain, bukan mulai proyek baru.", en: "Today's petung leans toward closing, so focus on finishing, not starting anything new." },
  }[petung.tone][l];

  if (!best) return baseLine;

  const timeLabel = `${String(best.hour).padStart(2, "0")}:00`;
  const activity = (PLANET_ACTIVITY[best.planet] || {})[l] || "";
  const hourLine = l === "en"
    ? ` If you can time it, ${timeLabel} is ruled by ${best.planet} — a good window for ${activity}.`
    : ` Kalau bisa diatur, jam ${timeLabel} diampu ${best.planet} — jendela bagus buat ${activity}.`;

  return baseLine + hourLine;
}

// ---- Intuition: kliwon status + moon phase + shio + pancasuda tone,
// framed as a spiritual/gut-feeling note. ----
function intuitionSection(reading, moon, lang) {
  const l = lang === "en" ? "en" : "id";
  const parts = [];

  if (reading.today.isKliwon) {
    parts.push(l === "en"
      ? "Today is Kliwon — the day traditionally read as having the thinnest veil between the seen and unseen. Trust the first read on something, even if you can't yet explain why."
      : "Hari ini Kliwon — hari yang secara tradisi dianggap paling tipis batas antara yang kelihatan dan yang nggak. Percaya firasat pertama soal sesuatu, walau belum bisa dijelasin kenapa.");
  }

  const mc = moonCategory(moon);
  if (mc === "full") {
    parts.push(l === "en"
      ? "With the moon full, whatever's been building emotionally will want to surface today — let it, rather than talking yourself out of feeling it."
      : "Bulan lagi purnama, apa pun yang udah numpuk secara emosional bakal pengen naik ke permukaan hari ini — biarin aja, jangan malah dibujuk buat nggak ngerasain.");
  } else if (mc === "new") {
    parts.push(l === "en"
      ? "With the moon new, intuition works better inward than outward today — a private notebook entry will tell you more than a conversation would."
      : "Bulan lagi mati, intuisi lebih kerja ke dalam daripada keluar hari ini — nulis diary bakal ngasih tau lebih banyak daripada ngobrol sama orang.");
  }

  const pt = reading.pancasuda.tone;
  if (pt === "guard") {
    parts.push(l === "en"
      ? "Your baseline temperament runs on friction, which means your gut warnings tend to be real more often than you give them credit for — don't override a bad feeling just to be polite."
      : "Watak dasarmu jalan di gesekan, artinya firasat burukmu biasanya lebih sering bener dari yang kamu kira — jangan nimpa perasaan nggak enak cuma demi sopan.");
  }

  if (parts.length === 0) {
    parts.push(l === "en"
      ? "Nothing unusual in the spiritual weather today — a good day to simply notice what your gut says without needing it to mean something bigger."
      : "Nggak ada yang khusus dari sisi spiritual hari ini — hari yang bagus buat sekadar merhatiin kata hati tanpa harus dimaknai jadi sesuatu yang besar.");
  }

  return parts.join(" ");
}

const PLANET_ALIGNED = {
  id: (dayRuler, sign) => `Ditambah, hari ini diampu ${dayRuler} yang pas nyambung sama elemen ${sign}-mu — orang bakal lebih gampang baca niatmu, jujur kerasa ringan.`,
  en: (dayRuler, sign) => `On top of that, ${dayRuler} rules today and lines up right with your ${sign} element — people read your intentions more easily, honesty feels light.`,
};
const PLANET_MISALIGNED = {
  id: (dayRuler) => `Ditambah, hari ini diampu ${dayRuler} — bukan elemen alami zodiakmu, jadi mungkin kamu harus kerja dikit lebih keras buat dipahami.`,
  en: (dayRuler) => `On top of that, ${dayRuler} rules today — not your zodiac's natural planet, so you might have to work a bit harder to be understood.`,
};

export function narrativeDailySynthesis(reading, moon, hour, lang = "id", now = new Date()) {
  const l = lang === "en" ? "en" : "id";
  const { birthWeton, today, petung, isWetonDay, sign, dayMasterRelationToday, bazi, baziToday } = reading;

  const gap = Math.abs(birthWeton.neptu - today.neptu);
  let foundationKey;
  if (isWetonDay) foundationKey = "wetonDay";
  else if (gap === 0) foundationKey = "same";
  else if (gap <= 2) foundationKey = "veryNear";
  else if (gap <= 5) foundationKey = "near";
  else if (gap <= 7) foundationKey = "far";
  else foundationKey = "veryFar";

  // Bazi accent clause for growth (secondary, weton stays primary)
  let baziClause = "", baziClauseEn = "";
  if (dayMasterRelationToday && bazi && baziToday) {
    const dm = ELEMENT_NAME[l][bazi.dayMaster.element];
    const te = ELEMENT_NAME[l][baziToday.day.stemElement];
    const REL_ID = {
      produces: ` Ditambah lagi, elemen hari ini (${te}) nyalain elemen intimu (${dm}) — energi ngalir makin gampang.`,
      produced_by: ` Ditambah lagi, elemen intimu (${dm}) lagi diisi ulang sama elemen hari ini (${te}) — bagus buat nerima, bukan ngasih.`,
      controls: ` Ditambah lagi, elemen hari ini (${te}) nekan elemen intimu (${dm}) — jaga energi ekstra hati-hati.`,
      controlled_by: ` Ditambah lagi, elemen intimu (${dm}) lagi unggul atas elemen hari ini (${te}) — modal buat ambil inisiatif.`,
      same: ` Ditambah lagi, elemen hari ini sewarna sama elemen intimu (${dm}) — identitasmu kerasa jelas banget.`,
      neutral: "",
    };
    const REL_EN = {
      produces: ` On top of that, today's element (${te}) feeds your core element (${dm}) — energy flows more easily.`,
      produced_by: ` On top of that, your core element (${dm}) is being refilled by today's element (${te}) — good for receiving, not giving.`,
      controls: ` On top of that, today's element (${te}) presses on your core element (${dm}) — guard your energy extra carefully.`,
      controlled_by: ` On top of that, your core element (${dm}) has the upper hand over today's element (${te}) — good ground for taking initiative.`,
      same: ` On top of that, today's element matches your core element (${dm}) — your identity feels especially clear.`,
      neutral: "",
    };
    baziClause = REL_ID[dayMasterRelationToday] || "";
    baziClauseEn = REL_EN[dayMasterRelationToday] || "";
  }

  const ctx = {
    birthWeton: birthWeton.label,
    todayWeton: today.label,
    todayNeptu: today.neptu,
    birthWeton_neptu: birthWeton.neptu,
    gap,
    sign: sign.name,
    petungKey: petung.key,
    petungMeaning: petung.meaning[l],
    day: today.day,
    dayMeaning: DAY_MEANING[l][today.day],
    baziClause,
    baziClauseEn,
  };

  const foundation = FOUNDATION[foundationKey](ctx)[l] + " " + MOON_TONE[moonCategory(moon)][l];
  const growth = GROWTH_TEXT[petung.tone](ctx)[l];

  const alignedFire = ["Mars", "Sun"].includes(hour.dayRuler) && sign.element === "fire";
  const alignedWater = hour.dayRuler === "Moon" && sign.element === "water";
  const alignedEarth = hour.dayRuler === "Saturn" && sign.element === "earth";
  const alignedAir = hour.dayRuler === "Mercury" && sign.element === "air";
  const aligned = alignedFire || alignedWater || alignedEarth || alignedAir;

  ctx.planetClause = aligned ? PLANET_ALIGNED.id(hour.dayRuler, sign.name) : PLANET_MISALIGNED.id(hour.dayRuler);
  ctx.planetClauseEn = aligned ? PLANET_ALIGNED.en(hour.dayRuler, sign.name) : PLANET_MISALIGNED.en(hour.dayRuler);
  ctx.pancasudaKey = reading.pancasuda.key;
  ctx.pancasudaFlavor = (PANCASUDA_FLAVOR[reading.pancasuda.key] || {}).id || "";
  ctx.pancasudaFlavorEn = (PANCASUDA_FLAVOR[reading.pancasuda.key] || {}).en || "";
  const connection = CONNECTION.base(ctx)[l];

  const energy = energySection(ctx, moon, bazi, lang);
  const decisions = decisionsSection(ctx, petung, hour, now, lang);
  const intuition = intuitionSection(reading, moon, lang);

  return { foundation, growth, connection, energy, decisions, intuition };
}

// ---- Birth-chart-only life reading, split by area. Blunt on purpose. ----

const LOVE_BY_PANCASUDA = {
  Sri: { id: "Orang gampang tertarik ke kamu tanpa kamu usaha keras — tapi itu juga bikin kamu jarang bener-bener diuji soal siapa yang mau tinggal pas susah, bukan cuma pas gampang.",
    en: "People are drawn to you without much effort on your part — which also means you rarely get tested on who actually stays through the hard parts, not just the easy ones." },
  Lungguh: { id: "Kamu cenderung jadi pihak yang 'dihormati' dalam hubungan, bukan yang paling dimanja. Kalau diam-diam pengen lebih dimanja, itu nggak bakal dateng sendiri — harus diomongin.",
    en: "You tend to be the 'respected' one in relationships, not the pampered one. If part of you quietly wants more affection, it won't show up on its own — you have to ask for it." },
  Gedhong: { id: "Kamu nyimpen perasaan lebih lama daripada ngomongin. Pasangan yang cocok itu yang sabar nunggu, bukan yang nuntut jujur instan.",
    en: "You sit on feelings longer than you voice them. The partner who fits you is patient, not one who demands instant openness." },
  Lara: { id: "Pola hubunganmu historisnya penuh gesekan, dan itu bukan kebetulan. Bukan kutukan, tapi juga bukan alasan buat terus nolerin yang emang udah ngerusak.",
    en: "Your relationship history runs on friction, and that's not a coincidence. It's not a curse, but it's also not a reason to keep tolerating what's genuinely harmful." },
  Pati: { id: "Kamu sering jadi yang 'nutup' hubungan — ngakhirin, beresin, jarang yang mulai duluan dengan ringan. Kuat kalau memang perlu selesai, tapi bisa jadi pola ngindar kalau kepake terlalu cepat.",
    en: "You're often the one who closes relationships — ending, wrapping up, rarely the one who starts lightly. That's a strength when things genuinely need to end, but it can be an avoidance pattern if it fires too early." },
};

const CAREER_BY_DOMINANT = {
  wood: { id: "Kamu tumbuh lewat mulai dan meluas, bukan lewat ngerawat yang udah ada. Kerjaan rutin tanpa ruang berkembang bakal kerasa kayak sesak napas, bukan sekadar bosan.",
    en: "You grow by starting and expanding, not by maintaining what already exists. Routine work with no room to grow will feel like suffocation, not just boredom." },
  fire: { id: "Kamu butuh kelihatan buat ngerasa hidup di kerjaan. Kalau posisimu sekarang bikin kamu invisible, itu bukan soal mood — emang nggak cocok sama wataknmu.",
    en: "You need to be seen to feel alive at work. If your current role makes you invisible, that's not a mood problem — it genuinely doesn't fit your wiring." },
  earth: { id: "Kamu paling kuat di posisi yang nopang orang lain — koordinator, penghubung, yang bikin semua orang tetep jalan. Sering diremehin, tapi itu langka.",
    en: "You're strongest in roles that hold other people up — coordinator, connector, the one keeping everything moving. Underrated, but rare." },
  metal: { id: "Kamu unggul di presisi dan standar, bukan di ambiguitas. Lingkungan kerja yang serba longgar bakal ngikis energimu pelan-pelan.",
    en: "You excel at precision and standards, not ambiguity. A loose, 'good enough' work environment will grind your energy down slowly." },
  water: { id: "Kamu adaptasi lebih cepet dari kebanyakan orang, tapi itu juga berarti kamu jarang bener-bener berhenti cukup lama buat liat hasil jangka panjangnya.",
    en: "You adapt faster than most people, which also means you rarely stay still long enough to see the long-term payoff." },
};

const HEALTH_BY_LACKING = {
  wood: { id: "Elemen Kayu absen di chart-mu — tradisi ngaitin ini sama hati dan fleksibilitas tubuh. Kecenderungannya: kamu keras ke diri sendiri dan lambat pulih dari kekakuan, fisik maupun emosional. Ini bacaan energetik, bukan diagnosis — kalau ada gejala nyata, itu urusan dokter.",
    en: "The Wood element is absent from your chart — tradition ties this to the liver and physical flexibility. The tendency: you're hard on yourself and slow to recover from rigidity, physical or emotional. This is an energetic reading, not a diagnosis — if something's actually wrong, see a doctor." },
  fire: { id: "Elemen Api absen di chart-mu — tradisi ngaitin ini sama jantung dan semangat. Kecenderungannya: energimu gampang padam dan butuh usaha sadar buat 'nyala', nggak otomatis. Ini bacaan energetik, bukan diagnosis.",
    en: "The Fire element is absent from your chart — tradition ties this to the heart and drive. The tendency: your energy dims easily and needs deliberate effort to 'switch on', it's not automatic. This is an energetic reading, not a diagnosis." },
  earth: { id: "Elemen Tanah absen di chart-mu — tradisi ngaitin ini sama pencernaan dan rasa stabil. Kecenderungannya: kamu lebih rentan ke gangguan yang berhubungan sama stres dan pola makan nggak teratur. Ini bacaan energetik, bukan diagnosis.",
    en: "The Earth element is absent from your chart — tradition ties this to digestion and groundedness. The tendency: you're more prone to issues tied to stress and irregular eating. This is an energetic reading, not a diagnosis." },
  metal: { id: "Elemen Logam absen di chart-mu — tradisi ngaitin ini sama paru-paru dan batas diri. Kecenderungannya: kamu susah bilang cukup, ke kerjaan maupun orang, sampai tubuh yang maksa berhenti. Ini bacaan energetik, bukan diagnosis.",
    en: "The Metal element is absent from your chart — tradition ties this to the lungs and personal boundaries. The tendency: you struggle to say enough, to work or to people, until your body forces the stop. This is an energetic reading, not a diagnosis." },
  water: { id: "Elemen Air absen di chart-mu — tradisi ngaitin ini sama ginjal dan cadangan energi jangka panjang. Kecenderungannya: kamu jalan di atas cadangan yang lebih tipis dari kelihatannya, dan capeknya numpuk diam-diam. Ini bacaan energetik, bukan diagnosis.",
    en: "The Water element is absent from your chart — tradition ties this to the kidneys and long-term energy reserves. The tendency: you're running on thinner reserves than it looks, and fatigue builds up quietly. This is an energetic reading, not a diagnosis." },
};

const HEALTH_DEFAULT = {
  id: "Kelima elemen muncul di chart-mu tanpa ada yang bener-bener absen — tradisi baca ini sebagai keseimbangan dasar yang cukup baik. Bukan berarti bebas masalah, tapi nggak ada satu titik lemah struktural yang jelas. Ini bacaan energetik, bukan diagnosis.",
  en: "All five elements show up in your chart with none completely absent — tradition reads this as a fairly solid baseline balance. Not problem-free, but no single obvious structural weak point. This is an energetic reading, not a diagnosis.",
};

export function lifeAreaReading(reading, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  const { pancasuda, bazi } = reading;

  const love = (LOVE_BY_PANCASUDA[pancasuda.key] || {})[l] || "";

  let career = "";
  if (bazi) {
    career = (CAREER_BY_DOMINANT[bazi.dominant] || {})[l] || "";
    const dm = ELEMENT_NAME[l][bazi.dayMaster.element];
    const relToDominant = elementRelation(bazi.dominant, bazi.dayMaster.element);
    if (relToDominant === "controls") {
      career += l === "en"
        ? ` There's structural tension between your chart's dominant element and your day master (${dm}) — you likely feel like you're working hard without matching results, until you notice you're fighting your own pattern, not just circumstances.`
        : ` Ada tekanan struktural antara elemen dominan chart-mu sama day master-mu (${dm}) — kemungkinan kamu sering ngerasa kerja keras tapi hasilnya nggak sebanding, sampai sadar kamu lagi ngelawan pola diri sendiri, bukan cuma keadaan.`;
    }
  }

  let health = "";
  if (bazi && bazi.lacking.length > 0) {
    health = bazi.lacking.map((e) => (HEALTH_BY_LACKING[e] || {})[l] || "").join(" ");
  } else if (bazi) {
    health = HEALTH_DEFAULT[l];
  }

  return { love, career, health };
}
