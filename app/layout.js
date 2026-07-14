import { Fraunces, Karla } from "next/font/google";
import Link from "next/link";
import "./globals.css";
import BottomNav from "../components/BottomNav";
import { LanguageProvider } from "../lib/i18n";
import LanguageToggle from "../components/LanguageToggle";
import Logo from "../components/Logo";

const fraunces = Fraunces({
  subsets: ["latin"],
  variable: "--font-display",
  weight: ["400", "500", "600"],
});
const karla = Karla({
  subsets: ["latin"],
  variable: "--font-body",
  weight: ["400", "500", "700"],
});

export const metadata = {
  title: "Niskala",
  description: "Energetic weather, dreams, and the botanical oracle.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={`${fraunces.variable} ${karla.variable}`}>
      <body>
        <LanguageProvider>
          <header className="app-header">
            <Link href="/" className="app-header-logo"><Logo /></Link>
            <LanguageToggle />
          </header>
          <main className="shell">{children}</main>
          <BottomNav />
        </LanguageProvider>
      </body>
    </html>
  );
}
