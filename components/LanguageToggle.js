"use client";

import { useLanguage } from "../lib/i18n";

export default function LanguageToggle() {
  const { lang, setLang } = useLanguage();
  return (
    <div className="lang-toggle" role="group" aria-label="Language">
      <button
        className={lang === "id" ? "lang-btn active" : "lang-btn"}
        onClick={() => setLang("id")}
      >
        ID
      </button>
      <button
        className={lang === "en" ? "lang-btn active" : "lang-btn"}
        onClick={() => setLang("en")}
      >
        EN
      </button>
    </div>
  );
}
