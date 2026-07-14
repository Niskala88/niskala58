"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { DECK, randomCardIndex } from "../../data/botanicals";
import { useLanguage } from "../../lib/i18n";

const MOON_FRAMES = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"];
const PULL_MESSAGES = {
  id: [
    "Mengocok lima puluh delapan daun",
    "Mendengarkan akar yang paling ribut",
    "Menunggu bulan menunjuk satu botani",
    "Menyaring dari dapur jamu",
    "Menimbang mana yang paling ingin bicara",
  ],
  en: [
    "Shuffling fifty-eight leaves",
    "Listening for the loudest root",
    "Waiting for the moon to point at one",
    "Sifting through the jamu pantry",
    "Weighing which one wants to speak",
  ],
};

export default function Oracle() {
  const { lang, t } = useLanguage();
  const router = useRouter();
  const [card, setCard] = useState(null);
  const [revealed, setRevealed] = useState(false);
  const [history, setHistory] = useState([]);
  const [authed, setAuthed] = useState(true);
  const [pulling, setPulling] = useState(false);
  const [moonFrame, setMoonFrame] = useState(0);
  const [msgIndex, setMsgIndex] = useState(0);
  const [pullError, setPullError] = useState("");
  const intervalRef = useRef(null);
  const msgRef = useRef(null);

  useEffect(() => {
    fetch("/api/pulls")
      .then((r) => {
        if (r.status === 401) { setAuthed(false); return { pulls: [] }; }
        return r.json();
      })
      .then((d) => {
        const pulls = d.pulls || [];
        setHistory(pulls);
        const today = new Date().toDateString();
        const todays = pulls.find(
          (p) => new Date(p.created_at).toDateString() === today
        );
        if (todays) {
          setCard(DECK.find((c) => c.id === todays.card_id) || null);
          setRevealed(true);
        }
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
      if (msgRef.current) clearInterval(msgRef.current);
    };
  }, []);

  async function pull() {
    setPullError("");
    setPulling(true);
    setMoonFrame(0);
    setMsgIndex(0);
    intervalRef.current = setInterval(
      () => setMoonFrame((f) => (f + 1) % MOON_FRAMES.length),
      280
    );
    msgRef.current = setInterval(
      () => setMsgIndex((i) => (i + 1) % PULL_MESSAGES[lang].length),
      1000
    );

    const idx = randomCardIndex(history[0]?.card_id || null);
    const c = DECK[idx];
    const minDelay = 3000 + Math.random() * 2000; // 3–5s of suspense

    const [res] = await Promise.all([
      fetch("/api/pulls", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ cardId: c.id }),
      }),
      new Promise((r) => setTimeout(r, minDelay)),
    ]);

    clearInterval(intervalRef.current);
    clearInterval(msgRef.current);
    setPulling(false);

    if (res.ok) {
      setCard(c);
      setRevealed(true);
      const list = await fetch("/api/pulls").then((r) => r.json());
      setHistory(list.pulls || []);
    } else if (res.status === 409) {
      const list = await fetch("/api/pulls").then((r) => r.json());
      const pulls = list.pulls || [];
      setHistory(pulls);
      const today = new Date().toDateString();
      const todays = pulls.find((p) => new Date(p.created_at).toDateString() === today);
      if (todays) {
        setCard(DECK.find((d) => d.id === todays.card_id) || null);
        setRevealed(true);
      }
      setPullError(t("oracle_already"));
    } else {
      setPullError(t("oracle_fail"));
    }
  }

  useEffect(() => {
    if (!authed) router.replace("/login");
  }, [authed, router]);

  if (!authed) return null;

  const recent = history.slice(0, 14);
  const counts = {};
  recent.forEach((p) => (counts[p.card_id] = (counts[p.card_id] || 0) + 1));
  const threads = Object.entries(counts)
    .filter(([, n]) => n >= 2)
    .map(([id, n]) => ({ card: DECK.find((d) => d.id === id), n }))
    .filter((entry) => entry.card);

  const locale = lang === "en" ? "en-GB" : "id-ID";

  return (
    <>
      <p className="eyebrow">{t("oracle_eyebrow")}</p>
      <h1>{t("oracle_title")}</h1>
      <p className="muted small">{t("oracle_sub")}</p>

      {pulling ? (
        <div className="oracle-card oracle-pulling">
          <div className="moon-spinner">{MOON_FRAMES[moonFrame]}</div>
          <p className="small muted" style={{ marginTop: 14 }}>{PULL_MESSAGES[lang][msgIndex]}…</p>
        </div>
      ) : !revealed ? (
        <div className="oracle-card">
          <p className="oracle-essence">{t("oracle_shuffled")}</p>
          <p className="muted small" style={{ margin: "10px 0 16px" }}>{t("oracle_58")}</p>
          <button className="btn-gold" onClick={pull}>{t("oracle_pull_button")}</button>
          {pullError && <p className="small" style={{ color: "var(--rosella)", marginTop: 10 }}>{pullError}</p>}
        </div>
      ) : card ? (
        <div className="oracle-card">
          <p className="oracle-essence">{card.essence}</p>
          <h2 className="oracle-name">{card.name}</h2>
          <p className="oracle-latin">{card.latin}</p>
          <p className="oracle-message">{card.message}</p>
          <div className="tend">
            <b>{t("oracle_tend")}</b> {card.tend}
          </div>
          {pullError && <p className="small muted" style={{ marginTop: 10 }}>{pullError}</p>}
        </div>
      ) : null}

      {threads.length > 0 && (
        <div className="card card-quiet">
          <h3 style={{ marginBottom: 6 }}>{t("oracle_threads")}</h3>
          {threads.map((entry) => (
            <p key={entry.card.id} className="small" style={{ marginBottom: 4 }}>
              <span className="pill pill-rose">{entry.card.name} ×{entry.n}</span>{" "}
              {t("oracle_thread_returning")} {entry.card.essence.toLowerCase()} {t("oracle_thread_season")}
            </p>
          ))}
        </div>
      )}

      {history.length > 0 && (
        <div style={{ marginTop: 18 }}>
          <h3>{t("oracle_history")}</h3>
          {history.slice(0, 10).map((p) => {
            const c = DECK.find((d) => d.id === p.card_id);
            return (
              <p key={p.id} className="small muted" style={{ marginTop: 6 }}>
                {new Date(p.created_at).toLocaleDateString(locale, {
                  day: "numeric", month: "short",
                })}{" "}
                · {c ? c.name : p.card_id}
              </p>
            );
          })}
        </div>
      )}
    </>
  );
}
