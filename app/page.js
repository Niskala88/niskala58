"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getWeton } from "../lib/javanese";
import { getMoon } from "../lib/moon";
import { getPlanetaryHour } from "../lib/planetary";
import { personalReading, dosAndDonts } from "../lib/astro";
import { narrativeDailySynthesis } from "../lib/synthesis";
import { ELEMENT_NAME } from "../lib/bazi";
import { useLanguage } from "../lib/i18n";

const RELATION_LABEL = {
  id: { produces: "menghidupi day master-mu", produced_by: "diisi ulang oleh day master-mu",
    controls: "menekan day master-mu", controlled_by: "dikendalikan day master-mu",
    same: "sewarna dengan day master-mu", neutral: "netral terhadap day master-mu" },
  en: { produces: "feeding your day master", produced_by: "being refilled by your day master",
    controls: "pressing on your day master", controlled_by: "controlled by your day master",
    same: "matching your day master", neutral: "neutral to your day master" },
};

export default function Home() {
  const { lang, t } = useLanguage();
  const router = useRouter();
  const [now, setNow] = useState(null);
  const [user, setUser] = useState(undefined);
  const [showDetail, setShowDetail] = useState(false);

  useEffect(() => {
    setNow(new Date());
    fetch("/api/me")
      .then((r) => r.json())
      .then((d) => setUser(d.user || null))
      .catch(() => setUser(null));
    const t = setInterval(() => setNow(new Date()), 60000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    if (user === null) router.replace("/login");
  }, [user, router]);

  if (!now || user === undefined || user === null) return null;

  const weton = getWeton(now);
  const moon = getMoon(now);
  const hour = getPlanetaryHour(now);

  let personal = null;
  if (user && user.birthDate) {
    const reading = personalReading(new Date(user.birthDate), user.birthTime, now);
    personal = {
      reading,
      narrative: narrativeDailySynthesis(reading, moon, hour, lang, now),
      ...dosAndDonts(reading, moon, hour, lang),
    };
  }

  const locale = lang === "en" ? "en-GB" : "id-ID";
  const dateLabel = now.toLocaleDateString(locale, {
    weekday: "long", day: "numeric", month: "long",
  });

  const upcoming = [];
  for (let i = 1; i <= 4; i++) {
    const d = new Date(now);
    d.setHours(d.getHours() + i, 0, 0, 0);
    upcoming.push({ offset: i, ...getPlanetaryHour(d) });
  }

  return (
    <>
      <p className="eyebrow">{t("home_eyebrow")}</p>
      <h1>{dateLabel}</h1>
      <p className="muted small">{moon.name} · {moon.illumination}% lit</p>

      {personal && (
        <>
          {personal.reading.isWetonDay && (
            <p className="small" style={{ color: "var(--kunyit)", marginTop: 14 }}>
              ✦ {t("weton_day_label")}
            </p>
          )}

          <div className="card" style={{ marginTop: 14 }}>
            <p className="small" style={{ lineHeight: 1.7 }}>{personal.narrative.foundation}</p>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: 6, fontSize: 15 }}>{t("section_growth")}</h3>
            <p className="small" style={{ lineHeight: 1.7 }}>{personal.narrative.growth}</p>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: 6, fontSize: 15 }}>{t("section_connection")}</h3>
            <p className="small" style={{ lineHeight: 1.7 }}>{personal.narrative.connection}</p>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: 6, fontSize: 15 }}>{t("section_energy")}</h3>
            <p className="small" style={{ lineHeight: 1.7 }}>{personal.narrative.energy}</p>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: 6, fontSize: 15 }}>{t("section_decisions")}</h3>
            <p className="small" style={{ lineHeight: 1.7 }}>{personal.narrative.decisions}</p>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: 6, fontSize: 15 }}>{t("section_intuition")}</h3>
            <p className="small" style={{ lineHeight: 1.7 }}>{personal.narrative.intuition}</p>
          </div>

          <div className="card card-quiet">
            <p className="small" style={{ color: "var(--sage)", marginBottom: 4 }}>{t("do_label")}</p>
            {personal.dos.map((d, i) => (
              <p key={i} className="small" style={{ marginBottom: 6 }}>· {d}</p>
            ))}
            {personal.donts.length > 0 && (
              <>
                <p className="small" style={{ color: "var(--rosella)", margin: "10px 0 4px" }}>{t("dont_label")}</p>
                {personal.donts.map((d, i) => (
                  <p key={i} className="small" style={{ marginBottom: 6 }}>· {d}</p>
                ))}
              </>
            )}
          </div>

          <button style={{ marginTop: 4 }} onClick={() => setShowDetail((s) => !s)}>
            {showDetail ? t("hide_detail") : t("show_detail")}
          </button>

          {showDetail && (
            <>
              <div className="card">
                <div className="weton-row">
                  <div className="weton-neptu">
                    <span className="n">{weton.neptu}</span>
                    <span className="l">neptu</span>
                  </div>
                  <div>
                    <h3>{weton.label}</h3>
                    <p className="small muted">{weton.meaning}</p>
                  </div>
                </div>
              </div>

              {personal.reading.bazi && (
                <div className="card">
                  <h3 style={{ marginBottom: 4 }}>{t("detail_bazi_today")}</h3>
                  <p className="small muted" style={{ marginBottom: 8 }}>
                    {t("detail_day_pillar")}: <b style={{ color: "var(--kunyit)" }}>
                      {personal.reading.baziToday.day.label} ({personal.reading.baziToday.day.hanzi})
                    </b>
                  </p>
                  <p className="small">
                    {t("detail_day_master")}: <b>{ELEMENT_NAME[lang][personal.reading.bazi.dayMaster.element]}</b>.{" "}
                    {t("detail_element_today")}: <b>{ELEMENT_NAME[lang][personal.reading.baziToday.day.stemElement]}</b>.{" "}
                    {t("detail_relation")}: <b>{RELATION_LABEL[lang][personal.reading.dayMasterRelationToday]}</b>.
                  </p>
                </div>
              )}

              <div className="card card-quiet">
                <p className="small muted" style={{ marginBottom: 4 }}>{t("detail_petung")}</p>
                <span className="pill pill-gold">{personal.reading.petung.key}</span>
                <p className="small" style={{ marginTop: 8 }}>{personal.reading.petung.meaning[lang]}</p>
              </div>

              <div className="card card-quiet">
                <h3 style={{ marginBottom: 4 }}>{t("detail_transit")}</h3>
                <p className="small muted" style={{ marginBottom: 8 }}>{t("detail_ruled_by")} {hour.dayRuler}</p>
                <span className="pill pill-gold">{t("detail_now")}: {hour.current}</span>
                <span className="pill">{t("detail_next")}: {hour.next}</span>
                <p className="small" style={{ marginTop: 10 }}>
                  <b style={{ color: "var(--kunyit)" }}>{hour.current}</b> — {hour.flavor}.
                </p>
                <p className="small muted" style={{ marginTop: 10, marginBottom: 4 }}>{t("detail_next_hours")}</p>
                {upcoming.map((u) => (
                  <p key={u.offset} className="small" style={{ marginBottom: 4 }}>
                    +{u.offset}h → <b>{u.current}</b> — {u.flavor}
                  </p>
                ))}
              </div>
            </>
          )}
        </>
      )}
    </>
  );
}
