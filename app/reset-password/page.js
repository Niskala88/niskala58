"use client";

import { useState, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { useLanguage } from "../../lib/i18n";

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

function ResetForm() {
  const router = useRouter();
  const params = useSearchParams();
  const token = params.get("token") || "";
  const { lang, t } = useLanguage();
  const [password, setPassword] = useState("");
  const [visible, setVisible] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  async function submit() {
    setError("");
    setLoading(true);
    try {
      const res = await fetch("/api/auth/reset", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token, newPassword: password, lang }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error || "—");
        setLoading(false);
        return;
      }
      setSuccess(true);
      setLoading(false);
    } catch {
      setError("—");
      setLoading(false);
    }
  }

  if (!token) {
    return (
      <>
        <h1>{t("forgot_title")}</h1>
        <p className="small" style={{ color: "var(--rosella)", marginTop: 12 }}>
          {t("reset_no_token")}
        </p>
        <Link href="/login" className="btn btn-gold" style={{ marginTop: 14 }}>{t("back_to_login")}</Link>
      </>
    );
  }

  if (success) {
    return (
      <>
        <h1>{t("forgot_title")}</h1>
        <p className="small" style={{ color: "var(--sage)", marginTop: 12 }}>{t("reset_success")}</p>
        <Link href="/login" className="btn btn-gold" style={{ marginTop: 14 }}>{t("back_to_login")}</Link>
      </>
    );
  }

  return (
    <>
      <h1>{t("forgot_title")}</h1>
      <p className="muted small">{t("reset_set_new")}</p>

      <div className="card">
        <label style={{ fontSize: 13, color: "var(--muted)", display: "block", marginBottom: 4 }}>{t("new_password")}</label>
        <div style={{ position: "relative" }}>
          <input
            type={visible ? "text" : "password"}
            placeholder={t("password_min")}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && submit()}
            style={{ paddingRight: 40 }}
          />
          <button
            type="button"
            onClick={() => setVisible((v) => !v)}
            aria-label={visible ? t("hide_password") : t("show_password")}
            style={{ position: "absolute", right: 6, top: 6, border: "none", background: "transparent", padding: 6, color: "var(--muted)", display: "flex", alignItems: "center" }}
          >
            <EyeIcon off={visible} />
          </button>
        </div>

        {error && <p className="small" style={{ color: "var(--rosella)", marginTop: 12 }}>{error}</p>}

        <button className="btn-gold" style={{ marginTop: 16 }} onClick={submit} disabled={loading}>
          {loading ? t("submitting") : t("submit_reset")}
        </button>
      </div>
    </>
  );
}

export default function ResetPassword() {
  return (
    <Suspense fallback={null}>
      <ResetForm />
    </Suspense>
  );
}
