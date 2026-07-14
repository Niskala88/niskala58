"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { sunSign, shio, personalReading, DAY_MEANING } from "../../lib/astro";
import { getPlanetaryHour } from "../../lib/planetary";
import { ELEMENT_NAME, ELEMENT_TRAIT } from "../../lib/bazi";
import { lifeAreaReading } from "../../lib/synthesis";
import { useLanguage } from "../../lib/i18n";

const ELEMENT_COLOR = {
  wood: "#7fa98d", fire: "#c4526b", earth: "#e3a94e", metal: "#c9c3e6", water: "#6d8fc4",
};

function PillarCard({ label, p, lang }) {
  if (!p) return null;
  return (
    <div className="pillar-card">
      <p className="pl-label">{label}</p>
      <p className="pl-hanzi">{p.hanzi}</p>
      <p className="pl-pinyin">{p.stemPinyin} {p.branchPinyin}</p>
      <p className="pl-element">{ELEMENT_NAME[lang][p.stemElement]} · {p.branchAnimal}</p>
    </div>
  );
}

function ElementBars({ counts, lang }) {
  const max = Math.max(1, ...Object.values(counts));
  return (
    <div className="element-bars">
      {Object.entries(counts).map(([el, n]) => (
        <div key={el} className="element-row">
          <span className="el-label">{ELEMENT_NAME[lang][el]}</span>
          <div className="el-track">
            <div className="el-fill" style={{ width: `${(n / max) * 100}%`, background: ELEMENT_COLOR[el] }} />
          </div>
          <span className="el-count">{n}</span>
        </div>
      ))}
    </div>
  );
}

export default function Profile() {
  const router = useRouter();
  const { lang, t } = useLanguage();
  const [user, setUser] = useState(undefined);
  const [now, setNow] = useState(null);

  useEffect(() => {
    setNow(new Date());
    fetch("/api/me")
      .then((r) => r.json())
      .then((d) => setUser(d.user || null))
      .catch(() => setUser(null));
  }, []);

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/login");
    router.refresh();
  }

  useEffect(() => {
    if (user === null) router.replace("/login");
  }, [user, router]);

  if (user === undefined || !now || user === null) return null;

  const birthDate = new Date(user.birthDate);
  const reading = personalReading(birthDate, user.birthTime, now);
  const { birthWeton, sign, pancasuda, bazi } = reading;
  const zodiacShio = shio(birthDate);
  const lifeAreas = lifeAreaReading(reading, lang);

  const hours = [];
  for (let h = 0; h < 24; h++) {
    const d = new Date(now);
    d.setHours(h, 0, 0, 0);
    hours.push({ h, planet: getPlanetaryHour(d).current });
  }
  const currentHour = now.getHours();
  const locale = lang === "en" ? "en-GB" : "id-ID";

  return (
    <>
      <p className="eyebrow">{t("profile_title")}</p>
      <h1>{user.name || user.email}</h1>
      <p className="muted small">
        {t("profile_born")} {birthDate.toLocaleDateString(locale, { day: "numeric", month: "long", year: "numeric" })}
        {user.birthTime ? ` · ${user.birthTime}` : ""}
        {user.birthPlace ? ` · ${user.birthPlace}` : ""}
      </p>

      <div className="section-divider">
        <h2>{t("section_weton")}</h2>
        <p className="muted small">{t("weton_sub")}</p>
      </div>

      <div className="card">
        <div className="weton-row">
          <div className="weton-neptu">
            <span className="n">{birthWeton.neptu}</span>
            <span className="l">neptu</span>
          </div>
          <div>
            <h3>{birthWeton.label}</h3>
            <p className="small muted">{birthWeton.meaning}</p>
          </div>
        </div>
        <p className="small" style={{ marginTop: 12 }}>
          <b style={{ color: "var(--kunyit)" }}>{birthWeton.day}</b>: {" "}
          {DAY_MEANING[lang][birthWeton.day]}.{" "}
          <b style={{ color: "var(--kunyit)" }}>{birthWeton.pasaran}</b>: {birthWeton.meaning}.
        </p>
        {birthWeton.isKliwon && (
          <p className="small" style={{ marginTop: 8, color: "var(--rosella)" }}>
            ✦ {t("kliwon_note")}
          </p>
        )}
      </div>

      <div className="card card-quiet">
        <p className="small">
          <b style={{ color: "var(--kunyit)" }}>{t("weton_howto")}</b> {t("weton_howto_body")}
        </p>
      </div>

      <div className="card card-quiet">
        <h3 style={{ marginBottom: 6 }}>{t("pancasuda_title")}</h3>
        <span className={pancasuda.tone === "open" ? "pill pill-gold" : pancasuda.tone === "guard" ? "pill pill-rose" : "pill"}>
          {pancasuda.key}
        </span>
        <p className="small" style={{ marginTop: 10 }}>{pancasuda.meaning[lang]}</p>
        <p className="small muted" style={{ marginTop: 8 }}>{t("pancasuda_note")}</p>
      </div>

      {bazi && (
        <>
          <div className="section-divider">
            <h2>{t("section_bazi")}</h2>
            <p className="muted small">
              {t("bazi_sub_prefix")}{!bazi.hour ? t("bazi_sub_no_hour") : ""} {t("bazi_sub_suffix")}
            </p>
          </div>

          <div className="card card-quiet">
            <p className="small">
              <b style={{ color: "var(--kunyit)" }}>{t("bazi_howto")}</b> {t("bazi_howto_body")}
            </p>
          </div>

          <div className="card">
            <div className="pillars">
              <PillarCard label="Y" p={bazi.year} lang={lang} />
              <PillarCard label="M" p={bazi.month} lang={lang} />
              <PillarCard label="D" p={bazi.day} lang={lang} />
              {bazi.hour && <PillarCard label="H" p={bazi.hour} lang={lang} />}
            </div>
            <p className="small" style={{ marginTop: 14 }}>
              {t("bazi_daymaster_prefix")} <b style={{ color: "var(--kunyit)" }}>{ELEMENT_NAME[lang][bazi.dayMaster.element]}</b>{" "}
              ({bazi.dayMaster.stem}, {bazi.dayMaster.polarity}) — {ELEMENT_TRAIT[lang][bazi.dayMaster.element]}.
            </p>
          </div>

          <div className="card card-quiet">
            <h3 style={{ marginBottom: 4 }}>{t("bazi_elements_title")}</h3>
            <p className="small muted" style={{ marginBottom: 4 }}>
              {t("bazi_elements_sub", bazi.hour ? "8" : "6")}
            </p>
            <ElementBars counts={bazi.elementCounts} lang={lang} />
            <p className="small" style={{ marginTop: 10 }}>
              {t("bazi_dominant_prefix")} <b style={{ color: "var(--kunyit)" }}>{ELEMENT_NAME[lang][bazi.dominant]}</b> — {ELEMENT_TRAIT[lang][bazi.dominant]}.
            </p>
            {bazi.lacking.length > 0 && (
              <p className="small muted" style={{ marginTop: 6 }}>
                {t("bazi_lacking_prefix")} {bazi.lacking.map((e) => ELEMENT_NAME[lang][e]).join(", ")} — {t("bazi_lacking_note")}
              </p>
            )}
          </div>
        </>
      )}

      {bazi && (
        <>
          <div className="section-divider">
            <h2>{t("section_conclusion")}</h2>
            <p className="muted small">{t("conclusion_sub")}</p>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: 6, color: "var(--rosella)" }}>{t("love")}</h3>
            <p className="small">{lifeAreas.love}</p>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: 6, color: "var(--kunyit)" }}>{t("career")}</h3>
            <p className="small">{lifeAreas.career}</p>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: 6, color: "var(--sage)" }}>{t("health")}</h3>
            <p className="small">{lifeAreas.health}</p>
          </div>
        </>
      )}

      <div className="section-divider">
        <h2>{t("section_zodiac")}</h2>
      </div>
      <div className="card card-quiet">
        <span className="pill pill-gold">{sign.name}</span>
        <span className="pill">{sign.element}</span>
        <span className="pill pill-rose">{zodiacShio.name}</span>
        {zodiacShio.approximate && (
          <p className="small muted" style={{ marginTop: 8 }}>{t("imlek_note")}</p>
        )}
      </div>

      <div className="section-divider">
        <h2>{t("section_planetary")}</h2>
        <p className="muted small">{t("planetary_sub")}</p>
      </div>

      {reading.birthHour && (
        <div className="card">
          <p className="small">
            {t("born_at_hour")} <b style={{ color: "var(--kunyit)" }}>{reading.birthHour.current}</b> —{" "}
            {reading.birthHour.flavor}. {t("birth_hour_note")}
          </p>
        </div>
      )}

      <div className="card card-quiet">
        <h3 style={{ marginBottom: 4 }}>{t("schedule_title")}</h3>
        <p className="small muted" style={{ marginBottom: 4 }}>{t("schedule_sub")}</p>
        <div className="hour-strip">
          {hours.map((h) => (
            <div key={h.h} className={`hour-chip${h.h === currentHour ? " now" : ""}`}>
              <div className="hc-time">{String(h.h).padStart(2, "0")}:00</div>
              <div className="hc-planet">{h.planet}</div>
            </div>
          ))}
        </div>
      </div>

      <button style={{ marginTop: 20 }} onClick={logout}>{t("logout")}</button>
    </>
  );
}
