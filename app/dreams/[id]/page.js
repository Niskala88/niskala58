"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { matchSymbols, genericReading, synthesizeOverall, personalDreamNote, findRecurringPattern } from "../../../lib/lexicon";
import { personalReading } from "../../../lib/astro";
import { useLanguage } from "../../../lib/i18n";

const LENSES = [
  { key: "jung", name: "Jungian", cls: "lens-jung", sub: { id: "simbol sebagai psike", en: "symbol as psyche" } },
  { key: "primbon", name: "Primbon Jawa", cls: "lens-primbon", sub: { id: "tafsir mimpi", en: "Javanese dream lore" } },
  { key: "islamic", name: "Islam (Ibn Sirin)", cls: "lens-islamic", sub: { id: "tradisi klasik", en: "classical tradition" } },
];

export default function DreamDetail() {
  const { id } = useParams();
  const router = useRouter();
  const { lang, t } = useLanguage();
  const [dream, setDream] = useState(null);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState("loading");
  const [user, setUser] = useState(null);
  const [history, setHistory] = useState([]);

  useEffect(() => {
    fetch("/api/me")
      .then((r) => r.json())
      .then((d) => setUser(d.user || null))
      .catch(() => {});
    fetch("/api/dreams")
      .then((r) => (r.ok ? r.json() : { dreams: [] }))
      .then((d) => setHistory(d.dreams || []))
      .catch(() => {});
  }, []);

  useEffect(() => {
    fetch(`/api/dreams/${id}`)
      .then((r) => {
        if (r.status === 401) { setStatus("unauthed"); return null; }
        if (!r.ok) { setStatus("notfound"); return null; }
        return r.json();
      })
      .then((d) => {
        if (d && d.dream) { setDream(d.dream); setStatus("ok"); }
      })
      .catch(() => setStatus("notfound"));
  }, [id]);

  async function interpret() {
    setLoading(true);
    let interpretations = null;

    let profile = null;
    if (user && user.birthDate) {
      try {
        const r = personalReading(new Date(user.birthDate), user.birthTime, new Date());
        profile = { pancasuda: r.pancasuda.key, sign: r.sign.name, dayMasterElement: r.bazi ? r.bazi.dayMaster.element : null };
      } catch {}
    }

    const pastTexts = history.filter((h) => h.id !== dream.id).map((h) => h.text);

    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 25000); // 25s max wait
      const res = await fetch("/api/interpret", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: dream.text, mood: dream.mood, lang, profile, pastDreams: pastTexts.slice(0, 8) }),
        signal: controller.signal,
      });
      clearTimeout(timeout);
      if (res.ok) {
        const data = await res.json();
        if (data && data.jung) interpretations = { source: "claude", ...data };
      }
    } catch {
      // Timed out, aborted, or network error — fall through to offline lexicon below.
    }

    if (!interpretations) {
      const hits = matchSymbols(dream.text);
      const personalNote = profile ? personalDreamNote(profile.pancasuda, lang) : "";
      const recurring = findRecurringPattern(hits, pastTexts, lang);
      if (hits.length > 0) {
        interpretations = {
          source: "lexicon",
          symbols: hits.map((h) => h.key),
          jung: hits.map((h) => h.jung[lang] || h.jung.id).join("\n\n"),
          primbon: hits.map((h) => h.primbon[lang] || h.primbon.id).join("\n\n"),
          islamic: hits.map((h) => h.islamic[lang] || h.islamic.id).join("\n\n"),
          overall: [synthesizeOverall(hits, dream.mood, lang), recurring, personalNote].filter(Boolean).join(" "),
        };
      } else {
        const generic = genericReading(dream.mood, lang);
        interpretations = {
          source: "generic", symbols: [], ...generic,
          overall: [synthesizeOverall([], dream.mood, lang), recurring, personalNote].filter(Boolean).join(" "),
        };
      }
    }

    const res = await fetch(`/api/dreams/${dream.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ interpretations }),
    });
    if (res.ok) {
      const { dream: updated } = await res.json();
      setDream(updated);
    }
    setLoading(false);
  }

  const locale = lang === "en" ? "en-GB" : "id-ID";

  if (status === "unauthed")
    return (
      <>
        <h1>{t("login_first")}</h1>
        <button style={{ marginTop: 12 }} onClick={() => router.push("/login")}>
          {t("to_login")}
        </button>
      </>
    );

  if (status === "notfound")
    return (
      <>
        <h1>{t("dream_not_found")}</h1>
        <button style={{ marginTop: 12 }} onClick={() => router.push("/dreams")}>
          {t("back")}
        </button>
      </>
    );

  if (!dream) return null;

  const interp = dream.interpretations;

  return (
    <>
      <p className="eyebrow">
        {new Date(dream.created_at).toLocaleDateString(locale, {
          weekday: "long", day: "numeric", month: "long",
        })}
        {dream.mood ? ` · ${dream.mood}` : ""}
      </p>
      <h1>{t("dream_detail_title")}</h1>
      <div className="card card-quiet">
        <p>{dream.text}</p>
      </div>

      {!interp && (
        <button className="btn-gold" style={{ marginTop: 16 }} onClick={interpret} disabled={loading}>
          {loading ? t("dream_interpreting") : t("dream_interpret_button")}
        </button>
      )}

      {loading && (
        <p className="muted small" style={{ marginTop: 10 }}>
          <span className="spin">☾</span> {t("dream_consulting")}
        </p>
      )}

      {interp && (
        <div style={{ marginTop: 18 }}>
          {interp.overall && (
            <div className="card" style={{ borderColor: "var(--kunyit-deep)" }}>
              <h3 style={{ marginBottom: 6, color: "var(--kunyit)" }}>{t("dream_overall_title")}</h3>
              <p className="small" style={{ lineHeight: 1.7 }}>{interp.overall}</p>
            </div>
          )}
          {interp.questions && interp.questions.length > 0 && (
            <div className="card card-quiet">
              <h3 style={{ marginBottom: 8, fontSize: 15 }}>{t("dream_questions_title")}</h3>
              {interp.questions.map((q, i) => (
                <p key={i} className="small" style={{ marginBottom: 6 }}>· {q}</p>
              ))}
            </div>
          )}
          <h2 style={{ marginTop: 18 }}>{t("dream_lenses_title")}</h2>
          <p className="muted small" style={{ marginBottom: 4 }}>{t("dream_lenses_sub")}</p>
          {interp.symbols && interp.symbols.length > 0 && (
            <div style={{ marginTop: 8 }}>
              {interp.symbols.map((s) => (
                <span key={s} className="pill pill-gold">{s}</span>
              ))}
            </div>
          )}
          {LENSES.map((l) =>
            interp[l.key] ? (
              <div key={l.key} className={`lens ${l.cls}`}>
                <p className="lens-name">{l.name}</p>
                <p className="small muted" style={{ marginBottom: 6 }}>{l.sub[lang]}</p>
                {interp[l.key].split("\n\n").map((para, i) => (
                  <p key={i} style={{ marginBottom: 8 }}>{para}</p>
                ))}
              </div>
            ) : null
          )}
          <p className="muted small" style={{ marginTop: 12 }}>
            {interp.source === "claude" ? t("dream_source_claude")
              : interp.source === "lexicon" ? t("dream_source_lexicon")
              : t("dream_source_generic")}
            {" "}{t("dream_source_suffix")}
          </p>
          <button style={{ marginTop: 12 }} onClick={interpret} disabled={loading}>
            {loading ? t("dream_interpreting") : t("dream_reinterpret_button")}
          </button>
        </div>
      )}
    </>
  );
}
