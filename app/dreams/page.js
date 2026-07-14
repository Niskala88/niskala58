"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useLanguage } from "../../lib/i18n";

const MOODS = { id: ["tenang", "aneh", "takut", "senang", "sedih", "vivid"], en: ["calm", "strange", "scared", "happy", "sad", "vivid"] };

export default function Dreams() {
  const router = useRouter();
  const { lang, t } = useLanguage();
  const [dreams, setDreams] = useState(null);
  const [authed, setAuthed] = useState(true);
  const [text, setText] = useState("");
  const [mood, setMood] = useState("");
  const [writing, setWriting] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetch("/api/dreams")
      .then((r) => {
        if (r.status === 401) { setAuthed(false); return { dreams: [] }; }
        return r.json();
      })
      .then((d) => setDreams(d.dreams || []))
      .catch(() => setDreams([]));
  }, []);

  async function submit() {
    if (!text.trim() || saving) return;
    setSaving(true);
    const res = await fetch("/api/dreams", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text: text.trim(), mood }),
    });
    if (res.ok) {
      const { dream } = await res.json();
      router.push(`/dreams/${dream.id}`);
    } else {
      setSaving(false);
    }
  }

  useEffect(() => {
    if (!authed) router.replace("/login");
  }, [authed, router]);

  const locale = lang === "en" ? "en-GB" : "id-ID";

  if (!authed) return null;

  return (
    <>
      <p className="eyebrow">{t("dreams_eyebrow")}</p>
      <h1>{t("dreams_title")}</h1>
      <p className="muted small">{t("dreams_sub")}</p>

      {!writing ? (
        <button className="btn-gold" style={{ marginTop: 16 }} onClick={() => setWriting(true)}>
          {t("dreams_log_button")}
        </button>
      ) : (
        <div className="card">
          <textarea
            rows={5}
            autoFocus
            placeholder={t("dreams_placeholder")}
            value={text}
            onChange={(e) => setText(e.target.value)}
          />
          <div style={{ marginTop: 10 }}>
            {MOODS[lang].map((m) => (
              <button
                key={m}
                className={mood === m ? "pill pill-gold" : "pill"}
                style={{ marginRight: 6 }}
                onClick={() => setMood(mood === m ? "" : m)}
              >
                {m}
              </button>
            ))}
          </div>
          <div style={{ marginTop: 12, display: "flex", gap: 8 }}>
            <button className="btn-gold" onClick={submit} disabled={saving}>
              {saving ? t("dreams_saving") : t("dreams_save")}
            </button>
            <button onClick={() => setWriting(false)}>{t("dreams_cancel")}</button>
          </div>
        </div>
      )}

      <div style={{ marginTop: 20 }}>
        {dreams && dreams.length === 0 && !writing && (
          <p className="muted small" style={{ marginTop: 16 }}>{t("dreams_empty")}</p>
        )}
        {(dreams || []).map((d) => (
          <Link key={d.id} href={`/dreams/${d.id}`} className="card dream-item">
            <p className="small muted">
              {new Date(d.created_at).toLocaleDateString(locale, {
                weekday: "short", day: "numeric", month: "short",
              })}
              {d.mood ? ` · ${d.mood}` : ""}
              {d.interpretations ? ` · ${t("dreams_interpreted")}` : ""}
            </p>
            <p style={{ marginTop: 4 }}>
              {d.text.length > 120 ? d.text.slice(0, 120) + "…" : d.text}
            </p>
          </Link>
        ))}
      </div>
    </>
  );
}
