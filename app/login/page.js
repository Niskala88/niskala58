"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useLanguage } from "../../lib/i18n";
import Logo from "../../components/Logo";

const EyeIcon = ({ off }) => (
  <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    {off ? (
      <>
        <path d="M17.94 17.94A10.94 10.94 0 0 1 12 20c-6 0-10-6-10-8a13.16 13.16 0 0 1 4.06-4.94M9.9 4.24A9.12 9.12 0 0 1 12 4c6 0 10 6 10 8a13.35 13.35 0 0 1-1.67 2.68M14.12 14.12a3 3 0 1 1-4.24-4.24" />
        <path d="M1 1l22 22" />
      </>
    ) : (
      <>
        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
        <circle cx="12" cy="12" r="3" />
      </>
    )}
  </svg>
);

function PasswordField({ label, placeholder, value, onChange, onKeyDown, t }) {
  const [visible, setVisible] = useState(false);
  return (
    <div style={{ position: "relative" }}>
      <label style={{ fontSize: 13, color: "var(--muted)", display: "block", marginTop: 12, marginBottom: 4 }}>{label}</label>
      <input
        type={visible ? "text" : "password"}
        placeholder={placeholder}
        value={value}
        onChange={onChange}
        onKeyDown={onKeyDown}
        style={{ paddingRight: 40 }}
      />
      <button
        type="button"
        onClick={() => setVisible((v) => !v)}
        aria-label={visible ? t("hide_password") : t("show_password")}
        style={{
          position: "absolute", right: 6, top: 30, border: "none", background: "transparent",
          padding: 6, color: "var(--muted)", display: "flex", alignItems: "center",
        }}
      >
        <EyeIcon off={visible} />
      </button>
    </div>
  );
}

export default function Login() {
  const router = useRouter();
  const { lang, t } = useLanguage();
  const [mode, setMode] = useState("login"); // login | signup | forgot
  const [form, setForm] = useState({
    email: "", password: "", name: "",
    birthDate: "", birthTime: "", birthPlace: "",
    newPassword: "",
  });
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [loading, setLoading] = useState(false);

  function set(key, value) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  function switchMode(next) {
    setMode(next);
    setError("");
    setSuccess("");
  }

  async function submit() {
    setError("");
    setSuccess("");
    setLoading(true);

    if (mode === "forgot") {
      try {
        const res = await fetch("/api/auth/forgot", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email: form.email, lang }),
        });
        const data = await res.json();
        if (!res.ok) {
          setError(data.error || "—");
          setLoading(false);
          return;
        }
        setSuccess(t("forgot_sent"));
        setLoading(false);
      } catch {
        setError("—");
        setLoading(false);
      }
      return;
    }

    const url = mode === "login" ? "/api/auth/login" : "/api/auth/signup";
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...form, lang }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error || "—");
        setLoading(false);
        return;
      }
      router.push("/");
      router.refresh();
    } catch {
      setError("—");
      setLoading(false);
    }
  }

  const label = { fontSize: 13, color: "var(--muted)", display: "block", marginTop: 12, marginBottom: 4 };

  return (
    <>
      <div style={{ display: "flex", justifyContent: "center", marginBottom: 12 }}>
        <Logo size="large" />
      </div>
      <h1 style={{ textAlign: "center" }}>
        {mode === "login" ? t("login_title") : mode === "signup" ? t("signup_title") : t("forgot_title")}
      </h1>
      <p className="muted small" style={{ textAlign: "center" }}>
        {mode === "login" ? t("login_sub") : mode === "signup" ? t("signup_sub") : t("forgot_sub")}
      </p>

      <div className="card">
        {mode !== "forgot" && (
          <>
            <label style={label}>{t("email")}</label>
            <input type="text" inputMode="email" autoComplete="email" placeholder="you@email.com"
              value={form.email} onChange={(e) => set("email", e.target.value)} />

            <PasswordField
              label={t("password")}
              placeholder={mode === "signup" ? t("password_min") : t("password")}
              value={form.password}
              onChange={(e) => set("password", e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && mode === "login" && submit()}
              t={t}
            />
          </>
        )}

        {mode === "signup" && (
          <>
            <label style={label}>{t("name_optional")}</label>
            <input type="text" placeholder={t("name_placeholder")} value={form.name}
              onChange={(e) => set("name", e.target.value)} />

            <label style={label}>{t("birth_date")}</label>
            <input type="date" value={form.birthDate}
              onChange={(e) => set("birthDate", e.target.value)} />

            <label style={label}>{t("birth_time")}</label>
            <input type="time" value={form.birthTime}
              onChange={(e) => set("birthTime", e.target.value)} />
            <p className="small muted" style={{ marginTop: 4 }}>{t("birth_time_note")}</p>

            <label style={label}>{t("birth_place")}</label>
            <input type="text" placeholder={t("birth_place_placeholder")} value={form.birthPlace}
              onChange={(e) => set("birthPlace", e.target.value)} />
          </>
        )}

        {mode === "forgot" && (
          <>
            <label style={label}>{t("email")}</label>
            <input type="text" inputMode="email" autoComplete="email" placeholder="you@email.com"
              value={form.email} onChange={(e) => set("email", e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && submit()} />
          </>
        )}

        {error && (
          <p className="small" style={{ color: "var(--rosella)", marginTop: 12 }}>{error}</p>
        )}
        {success && (
          <p className="small" style={{ color: "var(--sage)", marginTop: 12 }}>{success}</p>
        )}

        <div style={{ marginTop: 16, display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
          <button className="btn-gold" onClick={submit} disabled={loading}>
            {loading ? t("submitting")
              : mode === "login" ? t("submit_login")
              : mode === "signup" ? t("submit_signup")
              : t("submit_forgot")}
          </button>

          {mode !== "forgot" && (
            <button onClick={() => switchMode(mode === "login" ? "signup" : "login")}>
              {mode === "login" ? t("no_account") : t("have_account")}
            </button>
          )}
        </div>

        <div style={{ marginTop: 12 }}>
          {mode === "login" && (
            <button onClick={() => switchMode("forgot")} style={{ border: "none", background: "transparent", padding: 0, color: "var(--muted)", fontSize: 13, textDecoration: "underline" }}>
              {t("forgot_password")}
            </button>
          )}
          {mode === "forgot" && (
            <button onClick={() => switchMode("login")} style={{ border: "none", background: "transparent", padding: 0, color: "var(--muted)", fontSize: 13, textDecoration: "underline" }}>
              {t("back_to_login")}
            </button>
          )}
        </div>
      </div>
    </>
  );
}
