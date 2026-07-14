"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useLanguage } from "../lib/i18n";

const Icon = {
  home: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M19.1 4.9L17 7M7 17l-2.1 2.1" />
    </svg>
  ),
  dreams: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M21 13A9 9 0 1 1 11 3a7 7 0 0 0 10 10z" />
    </svg>
  ),
  oracle: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 2c1.5 4.5 3 6 7 7-4 1-5.5 2.5-7 7-1.5-4.5-3-6-7-7 4-1 5.5-2.5 7-7z" />
      <path d="M19 15c.6 1.8 1.2 2.4 3 3-1.8.6-2.4 1.2-3 3-.6-1.8-1.2-2.4-3-3 1.8-.6 2.4-1.2 3-3z" />
    </svg>
  ),
  profile: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="8" r="4" />
      <path d="M4 21c0-4 3.6-6 8-6s8 2 8 6" />
    </svg>
  ),
};

export default function BottomNav() {
  const pathname = usePathname();
  const { t } = useLanguage();
  if (pathname === "/login") return null;

  const TABS = [
    { href: "/", label: t("nav_today"), icon: "home" },
    { href: "/dreams", label: t("nav_dreams"), icon: "dreams" },
    { href: "/oracle", label: t("nav_oracle"), icon: "oracle" },
    { href: "/profile", label: t("nav_you"), icon: "profile" },
  ];

  return (
    <nav className="nav" aria-label="Main">
      {TABS.map((tab) => {
        const active =
          tab.href === "/" ? pathname === "/" : pathname.startsWith(tab.href);
        return (
          <Link key={tab.href} href={tab.href} className={active ? "active" : ""}>
            {Icon[tab.icon]}
            <span>{tab.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
