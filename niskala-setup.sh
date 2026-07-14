#!/bin/bash
# Niskala v1.1 — full project generator (auth + bazi + i18n + logo + reset password)
# Usage: paste this entire script into your Codespace terminal,
# or save as niskala-setup.sh and run: bash niskala-setup.sh
set -e
echo "Creating Niskala..."

cat > "README.md" << 'NISKALA_FILE_EOF'
# Niskala

Energetic weather, dreams, and the botanical oracle. A quiet esoteric companion app.

## Stack

- Next.js 14 (App Router), plain JS, no UI framework
- localStorage persistence (see `lib/storage.js` — swap for Postgres later without touching components)
- Optional Claude API for dream interpretation

## Run it

```bash
npm install
npm run dev
```

Open http://localhost:3000.

## Deploy to Vercel

Push to GitHub, import in Vercel, deploy. Zero config needed.

To unlock dream-specific interpretation (instead of the offline symbol
lexicon), add an environment variable in Vercel:

```
ANTHROPIC_API_KEY=sk-ant-...
```

## What's inside

- **Today** — energetic weather: weton (Javanese calendar, computed
  locally with real JDN math), moon phase and illumination, planetary
  hours (Chaldean order, equator-simplified 06:00–18:00 day arc), and a
  synthesized daily reading.
- **Dreams** — journal with mood tags. Interpretation through three
  lenses: Jungian, primbon Jawa, and the classical Islamic (Ibn Sirin)
  tradition. Uses Claude when an API key is set; falls back to the
  built-in bilingual symbol lexicon (`lib/lexicon.js`) otherwise.
- **Oracle** — a 16-card botanical deck drawn from the jamu pantry.
  Deterministic daily pull (same day, same card), with thread detection
  when a card recurs.

## Roadmap (phase 3)

- Sound sessions: intention-based tone + ambience stacks (Web Audio API)
- Ritual tracker synced to the lunar calendar, grimoire archive
- Weton compatibility and personal Bazi layer on the Today screen
- Voice-note dream capture (MediaRecorder + transcription)

## Notes

- Weton math verified against 17 Aug 1945 = Jumat Legi.
- Interpretations are framed as reflective traditions, not predictions.

## v0.2 — Auth + personal layer

New env vars needed (Vercel dashboard or `.env.local`):

```
POSTGRES_URL=postgres://...    # from Vercel Postgres / Neon
AUTH_SECRET=any-long-random-string
ANTHROPIC_API_KEY=sk-ant-...   # optional, for dream interpretation
RESEND_API_KEY=re_...          # optional, for email-based password reset
RESEND_FROM_EMAIL=Niskala <onboarding@resend.dev>  # optional override
```

Setup order:
1. `npm install` (new deps: @vercel/postgres, bcryptjs, jose)
2. Set env vars
3. Run the app, visit `/api/setup` once to create tables
4. Sign up at `/login` with birth date/time/place

What signup unlocks:
- Birth weton + neptu, sun sign, shio, and birth planetary hour (profile tab)
- Daily petung match (birth neptu vs today's neptu → Sri/Lungguh/Dunya/Lara/Pati)
- Personalized do's & don'ts synthesized from petung + moon + planetary day + weton-day detection (selapanan)
- Dreams and oracle pulls stored per-account in Postgres — any device, anytime
NISKALA_FILE_EOF

mkdir -p "app/api/auth/forgot"
cat > "app/api/auth/forgot/route.js" << 'NISKALA_FILE_EOF'
import { sql } from "@vercel/postgres";
import crypto from "crypto";
import { Resend } from "resend";

const COPY = {
  subject: { id: "Reset password Niskala", en: "Reset your Niskala password" },
  greeting: { id: "Halo", en: "Hi" },
  body1: {
    id: "Ada permintaan buat reset password akun Niskala kamu. Klik tombol di bawah untuk atur password baru — link ini berlaku 1 jam.",
    en: "Someone requested a password reset for your Niskala account. Click the button below to set a new password — this link is valid for 1 hour.",
  },
  button: { id: "Reset Password", en: "Reset Password" },
  ignore: {
    id: "Kalau bukan kamu yang minta ini, abaikan aja email ini — password kamu tetap aman.",
    en: "If you didn't request this, just ignore this email — your password is unchanged.",
  },
};

function emailHtml(link, lang) {
  const l = lang === "en" ? "en" : "id";
  return `
  <div style="font-family: -apple-system, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px 20px; background: #14101f; color: #ece7f6;">
    <p style="font-family: Georgia, serif; font-size: 24px; color: #e3a94e; margin-bottom: 24px;">Niskala</p>
    <p>${COPY.greeting[l]},</p>
    <p style="line-height: 1.6;">${COPY.body1[l]}</p>
    <p style="margin: 28px 0;">
      <a href="${link}" style="background: #e3a94e; color: #241a08; padding: 12px 24px; border-radius: 10px; text-decoration: none; font-weight: 600; display: inline-block;">${COPY.button[l]}</a>
    </p>
    <p style="font-size: 13px; color: #9c93b8; line-height: 1.6;">${COPY.ignore[l]}</p>
  </div>`;
}

export async function POST(request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }
  const { email, lang } = body || {};
  const l = lang === "en" ? "en" : "id";

  // Always respond the same way regardless of whether the email
  // exists, so this endpoint can't be used to check who has an
  // account here.
  const genericResponse = () => Response.json({ ok: true });

  if (!email || typeof email !== "string") return genericResponse();

  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    return Response.json(
      { error: l === "en" ? "Email service not configured yet." : "Layanan email belum dikonfigurasi." },
      { status: 503 }
    );
  }

  try {
    const { rows } = await sql`SELECT id FROM users WHERE email = ${email.toLowerCase()}`;
    if (rows.length === 0) return genericResponse();

    const token = crypto.randomBytes(32).toString("hex");
    const expires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour
    await sql`UPDATE users SET reset_token = ${token}, reset_token_expires = ${expires.toISOString()} WHERE id = ${rows[0].id}`;

    const origin = new URL(request.url).origin;
    const link = `${origin}/reset-password?token=${token}`;

    const resend = new Resend(apiKey);
    const { data, error: sendError } = await resend.emails.send({
      from: process.env.RESEND_FROM_EMAIL || "Niskala <onboarding@resend.dev>",
      to: email,
      subject: COPY.subject[l],
      html: emailHtml(link, l),
    });

    if (sendError) {
      // Resend's SDK often returns { error } instead of throwing —
      // e.g. sandbox mode only allows sending to the Resend
      // account's own verified email until a domain is verified.
      // Logged, not surfaced to the client (still don't want to
      // leak whether an email is registered).
      console.error("forgot-password: Resend rejected the send:", sendError);
    } else {
      console.log("forgot-password: email sent, id:", data?.id);
    }

    return genericResponse();
  } catch (err) {
    // Log the real reason server-side so it's debuggable from the
    // terminal, without leaking details to the client response.
    console.error("forgot-password error:", err);
    return Response.json(
      { error: l === "en" ? "Couldn't send the email — try again shortly." : "Gagal ngirim email — coba lagi sebentar lagi." },
      { status: 500 }
    );
  }
}
NISKALA_FILE_EOF

mkdir -p "app/api/auth/login"
cat > "app/api/auth/login/route.js" << 'NISKALA_FILE_EOF'
import { sql } from "@vercel/postgres";
import bcrypt from "bcryptjs";
import { createSession } from "../../../../lib/auth";

const MSG = {
  missing: { id: "Email dan password wajib diisi", en: "Email and password are required" },
  wrong: { id: "Email atau password salah", en: "Wrong email or password" },
  db_error: { id: "Database error — cek POSTGRES_URL", en: "Database error — check POSTGRES_URL" },
};

export async function POST(request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }
  const { email, password, lang } = body || {};
  const l = lang === "en" ? "en" : "id";
  if (!email || !password)
    return Response.json({ error: MSG.missing[l] }, { status: 400 });

  try {
    const { rows } = await sql`
      SELECT id, password_hash FROM users WHERE email = ${email.toLowerCase()}`;
    if (rows.length === 0)
      return Response.json({ error: MSG.wrong[l] }, { status: 401 });
    const ok = await bcrypt.compare(password, rows[0].password_hash);
    if (!ok)
      return Response.json({ error: MSG.wrong[l] }, { status: 401 });
    await createSession(rows[0].id);
    return Response.json({ ok: true });
  } catch {
    return Response.json({ error: MSG.db_error[l] }, { status: 500 });
  }
}
NISKALA_FILE_EOF

mkdir -p "app/api/auth/logout"
cat > "app/api/auth/logout/route.js" << 'NISKALA_FILE_EOF'
import { clearSession } from "../../../../lib/auth";

export async function POST() {
  clearSession();
  return Response.json({ ok: true });
}
NISKALA_FILE_EOF

mkdir -p "app/api/auth/reset"
cat > "app/api/auth/reset/route.js" << 'NISKALA_FILE_EOF'
import { sql } from "@vercel/postgres";
import bcrypt from "bcryptjs";

const MSG = {
  invalid: { id: "Link reset tidak valid atau sudah kedaluwarsa. Minta link baru.", en: "This reset link is invalid or has expired. Request a new one." },
  missing: { id: "Semua kolom wajib diisi", en: "All fields are required" },
  short_password: { id: "Password minimal 8 karakter", en: "Password must be at least 8 characters" },
  db_error: { id: "Database error — cek POSTGRES_URL", en: "Database error — check POSTGRES_URL" },
};

export async function POST(request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }

  const { token, newPassword, lang } = body || {};
  const l = lang === "en" ? "en" : "id";

  if (!token || !newPassword)
    return Response.json({ error: MSG.missing[l] }, { status: 400 });
  if (newPassword.length < 8)
    return Response.json({ error: MSG.short_password[l] }, { status: 400 });

  try {
    const { rows } = await sql`
      SELECT id FROM users
      WHERE reset_token = ${token} AND reset_token_expires > NOW()`;
    if (rows.length === 0)
      return Response.json({ error: MSG.invalid[l] }, { status: 401 });

    const hash = await bcrypt.hash(newPassword, 10);
    await sql`
      UPDATE users
      SET password_hash = ${hash}, reset_token = NULL, reset_token_expires = NULL
      WHERE id = ${rows[0].id}`;
    return Response.json({ ok: true });
  } catch {
    return Response.json({ error: MSG.db_error[l] }, { status: 500 });
  }
}
NISKALA_FILE_EOF

mkdir -p "app/api/auth/signup"
cat > "app/api/auth/signup/route.js" << 'NISKALA_FILE_EOF'
import { sql } from "@vercel/postgres";
import bcrypt from "bcryptjs";
import { createSession } from "../../../../lib/auth";

const MSG = {
  invalid_email: { id: "Email tidak valid", en: "Invalid email" },
  short_password: { id: "Password minimal 8 karakter", en: "Password must be at least 8 characters" },
  missing_birth: { id: "Tanggal lahir wajib diisi", en: "Birth date is required" },
  duplicate: { id: "Email sudah terdaftar", en: "Email is already registered" },
  db_error: { id: "Database error — cek POSTGRES_URL", en: "Database error — check POSTGRES_URL" },
};

export async function POST(request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }

  const { email, password, name, birthDate, birthTime, birthPlace, lang } = body || {};
  const l = lang === "en" ? "en" : "id";

  if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email))
    return Response.json({ error: MSG.invalid_email[l] }, { status: 400 });
  if (!password || password.length < 8)
    return Response.json({ error: MSG.short_password[l] }, { status: 400 });
  if (!birthDate || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate))
    return Response.json({ error: MSG.missing_birth[l] }, { status: 400 });

  const hash = await bcrypt.hash(password, 10);

  try {
    const { rows } = await sql`
      INSERT INTO users (email, password_hash, name, birth_date, birth_time, birth_place)
      VALUES (${email.toLowerCase()}, ${hash}, ${name || null}, ${birthDate}, ${birthTime || null}, ${birthPlace || null})
      RETURNING id`;
    await createSession(rows[0].id);
    return Response.json({ ok: true });
  } catch (e) {
    if (String(e).includes("duplicate") || String(e).includes("unique"))
      return Response.json({ error: MSG.duplicate[l] }, { status: 409 });
    return Response.json({ error: MSG.db_error[l] }, { status: 500 });
  }
}
NISKALA_FILE_EOF

mkdir -p "app/api/dreams/[id]"
cat > "app/api/dreams/[id]/route.js" << 'NISKALA_FILE_EOF'
import { sql } from "@vercel/postgres";
import { getUserId } from "../../../../lib/auth";

export async function GET(_request, { params }) {
  const userId = await getUserId();
  if (!userId) return Response.json({ error: "unauthorized" }, { status: 401 });
  const id = Number(params.id);
  if (!id) return Response.json({ error: "bad_request" }, { status: 400 });

  const { rows } = await sql`
    SELECT id, text, mood, interpretations, created_at
    FROM dreams WHERE id = ${id} AND user_id = ${userId}`;
  if (rows.length === 0)
    return Response.json({ error: "not_found" }, { status: 404 });
  return Response.json({ dream: rows[0] });
}

export async function PATCH(request, { params }) {
  const userId = await getUserId();
  if (!userId) return Response.json({ error: "unauthorized" }, { status: 401 });
  const id = Number(params.id);
  if (!id) return Response.json({ error: "bad_request" }, { status: 400 });

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }
  const { interpretations } = body || {};
  if (!interpretations)
    return Response.json({ error: "bad_request" }, { status: 400 });

  const { rows } = await sql`
    UPDATE dreams SET interpretations = ${JSON.stringify(interpretations)}
    WHERE id = ${id} AND user_id = ${userId}
    RETURNING id, text, mood, interpretations, created_at`;
  if (rows.length === 0)
    return Response.json({ error: "not_found" }, { status: 404 });
  return Response.json({ dream: rows[0] });
}
NISKALA_FILE_EOF

mkdir -p "app/api/dreams"
cat > "app/api/dreams/route.js" << 'NISKALA_FILE_EOF'
import { sql } from "@vercel/postgres";
import { getUserId } from "../../../lib/auth";

export async function GET() {
  const userId = await getUserId();
  if (!userId) return Response.json({ error: "unauthorized" }, { status: 401 });
  const { rows } = await sql`
    SELECT id, text, mood, interpretations, created_at
    FROM dreams WHERE user_id = ${userId}
    ORDER BY created_at DESC`;
  return Response.json({ dreams: rows });
}

export async function POST(request) {
  const userId = await getUserId();
  if (!userId) return Response.json({ error: "unauthorized" }, { status: 401 });

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }
  const { text, mood } = body || {};
  if (!text || typeof text !== "string" || text.length > 8000)
    return Response.json({ error: "bad_request" }, { status: 400 });

  const { rows } = await sql`
    INSERT INTO dreams (user_id, text, mood)
    VALUES (${userId}, ${text}, ${mood || null})
    RETURNING id, text, mood, interpretations, created_at`;
  return Response.json({ dream: rows[0] });
}
NISKALA_FILE_EOF

mkdir -p "app/api/interpret"
cat > "app/api/interpret/route.js" << 'NISKALA_FILE_EOF'
// POST /api/interpret — multi-lens dream interpretation via Claude.
// Requires ANTHROPIC_API_KEY in env. Returns 503 if not configured,
// and the client falls back to the offline lexicon.

export async function POST(request) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return Response.json({ error: "not_configured" }, { status: 503 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }

  const { text, mood, lang, profile, pastDreams } = body || {};
  if (!text || typeof text !== "string" || text.length > 4000) {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }
  const overallLang = lang === "en" ? "English" : "Indonesian";

  const profileLine = profile && (profile.pancasuda || profile.sign)
    ? `\nDreamer's own profile (weave this in only in the "overall" field, only if genuinely relevant — don't force it): pancasuda temperament "${profile.pancasuda || "unknown"}" (a Javanese weton-based baseline character trait), zodiac sign "${profile.sign || "unknown"}", core bazi element "${profile.dayMasterElement || "unknown"}".`
    : "";

  const historyBlock = Array.isArray(pastDreams) && pastDreams.length > 0
    ? `\nDreamer's recent past dreams, most recent first, for pattern-spotting only (don't interpret these individually, just note if today's dream echoes, contrasts, or continues something from them):\n${pastDreams.map((d, i) => `${i + 1}. """${String(d).slice(0, 300)}"""`).join("\n")}`
    : "";

  const prompt = `You are a genuinely skilled dream analyst writing for a dream journal app — think the depth of a real analytic session, not a fortune-cookie summary. The dreamer is Indonesian and may write in mixed Indonesian/English.

Dream to interpret today: """${text}"""
${mood ? `Mood on waking: ${mood}` : ""}
${profileLine}
${historyBlock}

Interpret this dream HOLISTICALLY and with real depth — as a single unfolding narrative, not a checklist of symbols translated one by one. For each of the three lenses below:
- Track the dream's SEQUENCE (what happened first, what followed, what shifted) and treat the order as meaningful, not incidental.
- Notice specific, odd, or emotionally-charged DETAILS in the dream's own wording — an unusual color, a repeated action, something that felt "off" — and build the interpretation around those specifics rather than generic symbol-dictionary meanings.
- Name the TENSION or QUESTION the dream seems to be sitting with, not just a single tidy meaning.
- If the dreamer's recent dreams are provided above, explicitly note any echo, escalation, or contrast with this dream where genuinely relevant — this is one of the most valuable things you can offer.
- Write 5-7 sentences per lens — enough room to actually reason through the dream, not just assert a conclusion. Write ALL THREE lenses (jung, primbon, islamic) in ${overallLang} — the dreamer selected ${overallLang} as their app language, so every field in your response must be in ${overallLang}, with no exceptions, even though these are culturally distinct traditions.

Then write two more fields:
- "overall": a ${overallLang} synthesis (5-7 sentences) that pulls the three lenses together — where they agree, where they genuinely diverge (don't manufacture disagreement if there isn't any), what the dream's central tension actually seems to be, and the most useful thing for the dreamer to sit with. If a dreamer profile was given and it's genuinely relevant, weave in one sentence connecting the dream to that pattern — otherwise skip it. Write this in your own voice, warm but direct, second person ("you"), not clinical.
- "questions": an array of exactly 2 short, specific, non-generic reflective questions (in ${overallLang}) that the dream itself raises for this dreamer — questions they could actually sit with, not "what does this mean to you" filler.

Respond with ONLY a JSON object, no markdown fences, in this exact shape:
{"symbols": ["up to 4 key symbols as short lowercase words"], "jung": "...", "primbon": "...", "islamic": "...", "overall": "...", "questions": ["...", "..."]}

For the islamic lens, draw on the classical Ibn Sirin tradition and keep a respectful, non-fatalistic tone (readings are possibilities, wallahu a'lam). Never predict death, illness, or disaster literally.`;

  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 1800,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!res.ok) {
      return Response.json({ error: "upstream" }, { status: 502 });
    }

    const data = await res.json();
    const raw = (data.content || [])
      .map((c) => (c.type === "text" ? c.text : ""))
      .join("");
    const clean = raw.replace(/```json|```/g, "").trim();
    const parsed = JSON.parse(clean);

    return Response.json({
      symbols: Array.isArray(parsed.symbols) ? parsed.symbols.slice(0, 4) : [],
      jung: String(parsed.jung || ""),
      primbon: String(parsed.primbon || ""),
      islamic: String(parsed.islamic || ""),
      overall: String(parsed.overall || ""),
      questions: Array.isArray(parsed.questions) ? parsed.questions.slice(0, 2).map(String) : [],
    });
  } catch {
    return Response.json({ error: "parse_failed" }, { status: 502 });
  }
}
NISKALA_FILE_EOF

mkdir -p "app/api/me"
cat > "app/api/me/route.js" << 'NISKALA_FILE_EOF'
import { sql } from "@vercel/postgres";
import { getUserId } from "../../../lib/auth";

export async function GET() {
  const userId = await getUserId();
  if (!userId) return Response.json({ user: null });

  try {
    const { rows } = await sql`
      SELECT id, email, name, birth_date, birth_time, birth_place
      FROM users WHERE id = ${userId}`;
    if (rows.length === 0) return Response.json({ user: null });
    const u = rows[0];
    return Response.json({
      user: {
        id: u.id,
        email: u.email,
        name: u.name,
        birthDate: u.birth_date,
        birthTime: u.birth_time,
        birthPlace: u.birth_place,
      },
    });
  } catch {
    return Response.json({ user: null, error: "db" }, { status: 500 });
  }
}
NISKALA_FILE_EOF

mkdir -p "app/api/pulls"
cat > "app/api/pulls/route.js" << 'NISKALA_FILE_EOF'
import { sql } from "@vercel/postgres";
import { getUserId } from "../../../lib/auth";

export async function GET() {
  const userId = await getUserId();
  if (!userId) return Response.json({ error: "unauthorized" }, { status: 401 });
  const { rows } = await sql`
    SELECT id, card_id, created_at FROM pulls
    WHERE user_id = ${userId}
    ORDER BY created_at DESC LIMIT 30`;
  return Response.json({ pulls: rows });
}

export async function POST(request) {
  const userId = await getUserId();
  if (!userId) return Response.json({ error: "unauthorized" }, { status: 401 });

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }
  const { cardId } = body || {};
  if (!cardId) return Response.json({ error: "bad_request" }, { status: 400 });

  // One pull per calendar day
  const { rows: existing } = await sql`
    SELECT id FROM pulls
    WHERE user_id = ${userId}
    AND created_at::date = NOW()::date`;
  if (existing.length > 0)
    return Response.json({ error: "already_pulled" }, { status: 409 });

  const { rows } = await sql`
    INSERT INTO pulls (user_id, card_id)
    VALUES (${userId}, ${cardId})
    RETURNING id, card_id, created_at`;
  return Response.json({ pull: rows[0] });
}
NISKALA_FILE_EOF

mkdir -p "app/api/setup"
cat > "app/api/setup/route.js" << 'NISKALA_FILE_EOF'
import { sql } from "@vercel/postgres";

// Visit /api/setup once after connecting a database.
export async function GET() {
  try {
    await sql`CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      name TEXT,
      birth_date DATE NOT NULL,
      birth_time TEXT,
      birth_place TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    )`;
    // ALTER, not just CREATE, so installs from before password reset
    // was added also get these columns without losing existing data.
    await sql`ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token TEXT`;
    await sql`ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token_expires TIMESTAMPTZ`;
    await sql`CREATE TABLE IF NOT EXISTS dreams (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      text TEXT NOT NULL,
      mood TEXT,
      interpretations JSONB,
      created_at TIMESTAMPTZ DEFAULT NOW()
    )`;
    await sql`CREATE TABLE IF NOT EXISTS pulls (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      card_id TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    )`;
    return Response.json({ ok: true, message: "Tables ready" });
  } catch (e) {
    return Response.json(
      { ok: false, error: "Database not reachable. Is POSTGRES_URL set?" },
      { status: 500 }
    );
  }
}
NISKALA_FILE_EOF

mkdir -p "app/dreams/[id]"
cat > "app/dreams/[id]/page.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "app/dreams"
cat > "app/dreams/page.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "app"
cat > "app/globals.css" << 'NISKALA_FILE_EOF'
:root {
  --ink: #14101f;
  --surface: #1e1830;
  --surface-2: #2a2240;
  --line: #3a3154;
  --moon: #ece7f6;
  --muted: #9c93b8;
  --kunyit: #e3a94e;
  --kunyit-deep: #8a5f1e;
  --rosella: #c4526b;
  --sage: #7fa98d;
  --radius: 14px;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  background: var(--ink);
  color: var(--moon);
  font-family: var(--font-body), sans-serif;
  font-size: 15.5px;
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
}

.shell {
  max-width: 520px;
  margin: 0 auto;
  padding: 28px 20px 110px;
  min-height: 100vh;
}

h1, h2, h3 { font-family: var(--font-display), serif; font-weight: 500; }
h1 { font-size: 30px; line-height: 1.2; letter-spacing: 0.01em; }
h2 { font-size: 20px; }
h3 { font-size: 17px; }

.eyebrow {
  font-size: 12px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--kunyit);
  margin-bottom: 6px;
}

.muted { color: var(--muted); }
.small { font-size: 13px; }

.card {
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: var(--radius);
  padding: 18px;
  margin-top: 14px;
}

.card-quiet { background: var(--surface-2); border: none; }

.pill {
  display: inline-block;
  font-size: 12.5px;
  padding: 4px 12px;
  border-radius: 999px;
  border: 1px solid var(--line);
  color: var(--muted);
  margin: 0 6px 6px 0;
}
.pill-gold { border-color: var(--kunyit-deep); color: var(--kunyit); }
.pill-rose { border-color: var(--rosella); color: var(--rosella); }

button, .btn {
  font-family: var(--font-body), sans-serif;
  font-size: 14.5px;
  font-weight: 500;
  background: transparent;
  color: var(--moon);
  border: 1px solid var(--line);
  border-radius: 10px;
  padding: 10px 16px;
  cursor: pointer;
  transition: background 0.15s ease, transform 0.05s ease;
  text-decoration: none;
  display: inline-block;
}
button:hover, .btn:hover { background: var(--surface-2); }
button:active, .btn:active { transform: scale(0.98); }
button:focus-visible, a:focus-visible, textarea:focus-visible {
  outline: 2px solid var(--kunyit);
  outline-offset: 2px;
}

.btn-gold {
  background: var(--kunyit);
  color: #241a08;
  border-color: var(--kunyit);
}
.btn-gold:hover { background: #eebb69; }

textarea, input[type="text"] {
  width: 100%;
  background: var(--surface-2);
  border: 1px solid var(--line);
  border-radius: 10px;
  color: var(--moon);
  font-family: var(--font-body), sans-serif;
  font-size: 15px;
  padding: 12px;
  resize: vertical;
}
textarea::placeholder, input::placeholder { color: var(--muted); }

/* Lens cards — the signature element */
.lens {
  border-radius: 0;
  border-left: 3px solid var(--line);
  padding: 14px 16px;
  margin-top: 12px;
  background: var(--surface);
}
.lens-jung { border-left-color: var(--kunyit); }
.lens-primbon { border-left-color: var(--sage); }
.lens-islamic { border-left-color: var(--rosella); }
.lens .lens-name {
  font-family: var(--font-display), serif;
  font-size: 15px;
  margin-bottom: 4px;
}
.lens p { font-size: 14.5px; color: var(--moon); }
.lens .small { color: var(--muted); }

/* Oracle card */
.oracle-card {
  background: var(--surface);
  border: 1px solid var(--kunyit-deep);
  border-radius: 18px;
  padding: 26px 22px;
  text-align: center;
  margin-top: 16px;
}
.oracle-essence {
  font-family: var(--font-display), serif;
  font-style: italic;
  color: var(--kunyit);
  font-size: 15px;
}
.oracle-name { font-size: 28px; margin: 6px 0 2px; }
.oracle-latin { font-size: 13px; color: var(--muted); font-style: italic; }
.oracle-message { margin-top: 14px; text-align: left; }
.tend {
  margin-top: 14px;
  padding: 12px 14px;
  background: var(--surface-2);
  border-radius: 10px;
  font-size: 14px;
  text-align: left;
}
.tend b { color: var(--kunyit); font-weight: 700; }

/* Weton dial */
.weton-row { display: flex; gap: 14px; align-items: center; }
.weton-neptu {
  min-width: 64px; height: 64px;
  border-radius: 50%;
  border: 1.5px solid var(--kunyit);
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  font-family: var(--font-display), serif;
}
.weton-neptu .n { font-size: 24px; color: var(--kunyit); line-height: 1; }
.weton-neptu .l { font-size: 10px; color: var(--muted); letter-spacing: 0.08em; text-transform: uppercase; }

/* Bottom nav */
.nav {
  position: fixed;
  bottom: 0; left: 0; right: 0;
  background: rgba(20, 16, 31, 0.92);
  backdrop-filter: blur(10px);
  border-top: 1px solid var(--line);
  display: flex;
  justify-content: space-around;
  padding: 10px 8px calc(10px + env(safe-area-inset-bottom));
  max-width: 100%;
}
.nav a {
  color: var(--muted);
  text-decoration: none;
  font-size: 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 3px;
  min-width: 72px;
}
.nav a.active { color: var(--kunyit); }
.nav svg { width: 22px; height: 22px; }

.dream-item { display: block; text-decoration: none; color: inherit; }
.dream-item:hover { border-color: var(--kunyit-deep); }

/* Bazi pillars */
.pillars {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(72px, 1fr));
  gap: 8px;
  margin-top: 12px;
}
.pillar-card {
  background: var(--surface-2);
  border-radius: 10px;
  padding: 10px 6px;
  text-align: center;
}
.pillar-card .pl-label { font-size: 10px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 6px; }
.pillar-card .pl-hanzi { font-family: var(--font-display), serif; font-size: 22px; color: var(--kunyit); line-height: 1.1; }
.pillar-card .pl-pinyin { font-size: 11px; color: var(--moon); margin-top: 4px; }
.pillar-card .pl-element { font-size: 10px; color: var(--muted); margin-top: 2px; }

.element-bars { margin-top: 12px; }
.element-row { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
.element-row .el-label { width: 52px; font-size: 12.5px; color: var(--muted); flex-shrink: 0; }
.element-row .el-track { flex: 1; height: 8px; background: var(--surface-2); border-radius: 4px; overflow: hidden; }
.element-row .el-fill { height: 100%; border-radius: 4px; }
.element-row .el-count { width: 16px; font-size: 12px; color: var(--muted); text-align: right; flex-shrink: 0; }

.section-divider {
  margin-top: 28px;
  margin-bottom: 4px;
}
.section-divider h2 { margin-bottom: 2px; }

.hour-strip {
  display: flex;
  overflow-x: auto;
  gap: 6px;
  margin-top: 10px;
  padding-bottom: 4px;
}
.hour-chip {
  flex-shrink: 0;
  min-width: 54px;
  text-align: center;
  background: var(--surface-2);
  border-radius: 8px;
  padding: 8px 4px;
  font-size: 11px;
}
.hour-chip.now { background: var(--kunyit); color: #241a08; }
.hour-chip .hc-time { color: var(--muted); font-size: 10px; }
.hour-chip.now .hc-time { color: #4a3410; }
.hour-chip .hc-planet { font-weight: 600; margin-top: 2px; }

.app-header {
  position: sticky;
  top: 0;
  z-index: 50;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 20px;
  max-width: 520px;
  margin: 0 auto;
  background: rgba(20, 16, 31, 0.92);
  backdrop-filter: blur(10px);
  border-bottom: 1px solid var(--line);
}
.app-header-logo { display: flex; align-items: center; }

.lang-toggle {
  display: flex;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 3px;
  gap: 2px;
}
.lang-btn {
  border: none;
  padding: 4px 10px;
  font-size: 11px;
  font-weight: 700;
  border-radius: 999px;
  background: transparent;
  color: var(--muted);
}
.lang-btn.active {
  background: var(--kunyit);
  color: #241a08;
}
.lang-btn:hover { background: var(--surface-2); }
.lang-btn.active:hover { background: #eebb69; }

.oracle-pulling {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 180px;
}
.moon-spinner {
  font-size: 52px;
  line-height: 1;
  animation: moon-pulse 0.9s ease-in-out infinite;
}
@keyframes moon-pulse {
  0%, 100% { transform: scale(1); opacity: 0.85; }
  50% { transform: scale(1.12); opacity: 1; }
}

.spin {
  display: inline-block;
}
@keyframes spin { to { transform: rotate(360deg); } }

@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; transition: none !important; }
}
NISKALA_FILE_EOF

mkdir -p "app"
cat > "app/layout.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "app/login"
cat > "app/login/page.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "app/oracle"
cat > "app/oracle/page.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "app"
cat > "app/page.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "app/profile"
cat > "app/profile/page.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "app/reset-password"
cat > "app/reset-password/page.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "components"
cat > "components/BottomNav.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "components"
cat > "components/LanguageToggle.js" << 'NISKALA_FILE_EOF'
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
NISKALA_FILE_EOF

mkdir -p "components"
cat > "components/Logo.js" << 'NISKALA_FILE_EOF'
export default function Logo({ size = "small" }) {
  const height = size === "large" ? 100 : 36;
  return (
    <img
      src="/logo.png"
      alt="Niskala"
      style={{ height, width: "auto", display: "block" }}
    />
  );
}
NISKALA_FILE_EOF

mkdir -p "data"
cat > "data/botanicals.js" << 'NISKALA_FILE_EOF'
// The botanical oracle deck. 16 cards drawn from the jamu pantry
// and the green witch cabinet. Each card: essence, upright message,
// and a "tend" — a small embodied action.

export const DECK = [
  { id: "temulawak", name: "Temulawak", latin: "Curcuma zanthorrhiza", essence: "Deep restoration", message: "The liver of the spirit. What heals you now is slow, unglamorous, and repeated daily — not a breakthrough but a rebuilding.", tend: "Do one boring restorative thing today and let it count." },
  { id: "kunyit", name: "Kunyit", latin: "Curcuma longa", essence: "Golden clarity", message: "Inflammation of the heart — old irritation held in the body. Kunyit asks you to name what has been quietly bothering you and cool it deliberately.", tend: "Say the irritating thing out loud once, to yourself or the wall." },
  { id: "kencur", name: "Kencur", latin: "Kaempferia galanga", essence: "The warm voice", message: "Kencur soothes the throat: something wants to be said gently rather than swallowed. Your voice carries further when it is warm, not sharp.", tend: "Send the soft version of the message you've been drafting." },
  { id: "jahe", name: "Jahe merah", latin: "Zingiber officinale", essence: "Ignition", message: "Cold has settled somewhere — a project, a friendship, your own ambition. Red ginger is permission to reheat it without apology.", tend: "Take the first visible step on the stalled thing, today." },
  { id: "sereh", name: "Sereh", latin: "Cymbopogon citratus", essence: "Cutting through", message: "Lemongrass clears stagnant air. A space — physical or social — needs sweeping. What smells stale probably is.", tend: "Clear one surface completely. Notice what you feel." },
  { id: "rosella", name: "Rosella", latin: "Hibiscus sabdariffa", essence: "The red gate", message: "Sourness that enlivens. Rosella marks a threshold of feeling — let yourself want what you want at full color instead of pastel.", tend: "Wear or touch something red. Mean it." },
  { id: "pandan", name: "Pandan", latin: "Pandanus amaryllifolius", essence: "Sweet patience", message: "Pandan perfumes slowly, from within the weave. Your influence right now works the same way — quiet, ambient, unmistakable in time.", tend: "Do the kind thing that no one will trace back to you." },
  { id: "asam", name: "Asam jawa", latin: "Tamarindus indica", essence: "Ripened sourness", message: "Tamarind is sour young and complex when aged. An old disappointment is ready to be re-tasted — it may have fermented into wisdom.", tend: "Revisit one old note, photo, or draft without judgment." },
  { id: "sirih", name: "Sirih", latin: "Piper betle", essence: "The protector", message: "The leaf of boundaries and honored guests. Someone or something needs to be formally welcomed — or formally shown the door.", tend: "State one boundary in plain words, without cushioning." },
  { id: "kayu-manis", name: "Kayu manis", latin: "Cinnamomum burmannii", essence: "Sweet fire", message: "Warmth that draws people close. This is a card of hosting, of sweetening the pot — abundance follows generosity here, not caution.", tend: "Feed someone. Literally if possible." },
  { id: "cengkeh", name: "Cengkeh", latin: "Syzygium aromaticum", essence: "The nail", message: "Clove numbs pain and fixes things in place. Decide one thing and drive the nail — the wobble is costing more than a wrong choice would.", tend: "Make the small pending decision before sunset." },
  { id: "beras", name: "Beras", latin: "Oryza sativa", essence: "The mother grain", message: "Beras is the base of every jamu and every table — foundation before flourish. Return to fundamentals: sleep, food, breath, ledger.", tend: "Check on your actual basics. One honest look." },
  { id: "melati", name: "Melati", latin: "Jasminum sambac", essence: "Night blooming", message: "Melati opens in darkness. What you are becoming is developing off-stage, in privacy — resist the urge to exhibit it early.", tend: "Keep one good thing secret today, on purpose." },
  { id: "kelor", name: "Kelor", latin: "Moringa oleifera", essence: "The humble powerhouse", message: "Dunia tak selebar daun kelor — but the leaf itself feeds villages. Something small in your life is far more nourishing than it looks.", tend: "Thank one 'small' thing or person concretely." },
  { id: "secang", name: "Secang", latin: "Biancaea sappan", essence: "Hidden color", message: "Secang wood looks plain until water finds it, then blooms red. A hidden quality of yours activates only in the right medium — seek that medium.", tend: "Put yourself in the room where your color shows." },
  { id: "akar-alang", name: "Akar alang-alang", latin: "Imperata cylindrica", essence: "The cooling root", message: "The weed everyone curses, the root that cools fevers. Reframe the invasive thing in your life — its persistence might be its medicine.", tend: "Name one 'weed' in your week and find its use." },
  { id: "daun-kelor2", name: "Daun salam", latin: "Syzygium polyanthum", essence: "The quiet seasoning", message: "Salam works in the background, never the star, always necessary. Your unglamorous, ongoing contribution matters more than it's being credited for.", tend: "Keep doing the quiet thing. No announcement needed." },
  { id: "temu-ireng", name: "Temu ireng", latin: "Curcuma aeruginosa", essence: "The bitter cleanse", message: "The dark cousin of temulawak, bitter and purging. Something in you needs to be expelled, not soothed — an old resentment, a habit past its use.", tend: "Write the bitter truth down, then physically discard the paper." },
  { id: "daun-sirsak", name: "Daun sirsak", latin: "Annona muricata", essence: "The deep rest", message: "Soursop leaf is steeped for sleep and recovery. Your nervous system is asking for a full stop, not a shorter to-do list.", tend: "Cancel one thing this week. Just cancel it." },
  { id: "adas", name: "Adas", latin: "Foeniculum vulgare", essence: "Sweet digestion", message: "Fennel eases what sits heavy in the gut — literally and metaphorically. Something you've swallowed needs help moving through, not more holding.", tend: "Talk through the heavy thing with someone who'll just listen." },
  { id: "kapulaga", name: "Kapulaga", latin: "Elettaria cardamomum", essence: "Aromatic elevation", message: "Cardamom lifts a whole dish with a small amount. A small gesture from you will carry more weight than you expect right now.", tend: "Do the small kind thing you've been underrating." },
  { id: "daun-jeruk", name: "Daun jeruk purut", latin: "Citrus hystrix", essence: "The sharp brightener", message: "One torn leaf changes an entire pot. You have more influence on the room's mood than you're currently using.", tend: "Say the bright, true thing you've been softening." },
  { id: "lengkuas", name: "Lengkuas", latin: "Alpinia galanga", essence: "The firm base", message: "Galangal is woodier and sterner than its ginger cousins — structure before flavor. Build the boring scaffolding before you decorate.", tend: "Do the structural task you've been skipping for the fun one." },
  { id: "daun-pepaya", name: "Daun pepaya", latin: "Carica papaya", essence: "The bitter tenderizer", message: "Papaya leaf breaks down what's tough — literally used to tenderize meat. A tough situation is being softened by time, even if you can't feel it yet.", tend: "Revisit something that felt impossible a month ago. Test if it's softer now." },
  { id: "brotowali", name: "Brotowali", latin: "Tinospora crispa", essence: "The honest bitterness", message: "Famously, unapologetically bitter — used precisely because it doesn't pretend. Someone needs the unsweetened version of your feedback.", tend: "Give the direct answer instead of the diplomatic one, once." },
  { id: "meniran", name: "Meniran", latin: "Phyllanthus niruri", essence: "The quiet immune builder", message: "Small, humble, and steadily strengthening from within. Your resilience right now is being built by unremarkable daily habits, not a single big fix.", tend: "Do the small daily maintenance thing instead of hunting a shortcut." },
  { id: "sambiloto", name: "Sambiloto", latin: "Andrographis paniculata", essence: "The bitter shield", message: "Used against fever and infection — it fights precisely by being uncompromising. Set the boundary that protects you, even if it tastes unpleasant to enforce.", tend: "Enforce the boundary you've been letting slide." },
  { id: "daun-kemangi", name: "Daun kemangi", latin: "Ocimum basilicum", essence: "The fresh interruption", message: "Basil cuts through richness, resets the palate. You need one genuinely fresh input this week — new place, new voice, new food.", tend: "Do one thing you've never done before, however small." },
  { id: "kayu-secang2", name: "Bunga telang", latin: "Clitoria ternatea", essence: "The color-changing bloom", message: "Butterfly pea shifts from blue to purple with a drop of acid. You are allowed to change color depending on what's added to your day — that's not inconsistency, that's chemistry.", tend: "Let your mood shift honestly today instead of performing steadiness." },
  { id: "jinten-hitam", name: "Jinten hitam", latin: "Nigella sativa", essence: "The ancient remedy", message: "Called by some traditions a cure for everything but death — a reminder that some things really are foundational. Return to the one practice you know works.", tend: "Do the one basic thing you know helps, no matter how unoriginal." },
  { id: "kayu-manis2", name: "Daun mint", latin: "Mentha", essence: "The cooling shock", message: "Mint cools on contact but leaves a lasting warmth after. Your first reaction to something hard may feel cold — trust that warmth follows.", tend: "Give yourself permission to react coolly before you have to be warm." },
  { id: "daun-sereh2", name: "Daun jambu biji", latin: "Psidium guajava", essence: "The gut settler", message: "Guava leaf is reached for when things move too fast internally — grief, anxiety, disorder. Something needs to slow its pace inside you.", tend: "Do the slowest version of your next task on purpose." },
  { id: "temu-kunci", name: "Temu kunci", latin: "Boesenbergia rotunda", essence: "The key root", message: "Its name literally means 'key root' — small, easy to miss, but it unlocks the dish. There is a small overlooked factor unlocking your current situation.", tend: "Ask what the small unnoticed variable is, out loud, to someone." },
  { id: "daun-sirih-merah", name: "Sirih merah", latin: "Piper crocatum", essence: "The stronger protector", message: "A more intense cousin of sirih — used when ordinary protection isn't enough. Some situation calls for a firmer stance than your default.", tend: "Take the firmer stance you've been avoiding, once." },
  { id: "kunyit-putih", name: "Kunyit putih", latin: "Curcuma zedoaria", essence: "The pale clarity", message: "Paler and gentler than common turmeric — clarity that doesn't need to be loud. Your insight this week doesn't need to be dramatic to be right.", tend: "Trust the quiet realization instead of waiting for a bigger sign." },
  { id: "daun-kelapa", name: "Daun pandan wangi", latin: "Pandanus amaryllifolius (whole leaf)", essence: "The fragrant wrap", message: "Pandan wraps and perfumes food from the outside in. Consider how you're presenting something — the container may need attention as much as the contents.", tend: "Improve the presentation of something you've been neglecting, not the substance." },
  { id: "kayu-cendana", name: "Kayu cendana", latin: "Santalum album", essence: "The lasting scent", message: "Sandalwood's fragrance outlasts the wood itself. What you do today may outlast the moment it happened in — act with that in mind.", tend: "Do one thing today thinking about who it will reach in a year." },
  { id: "bunga-kenanga", name: "Bunga kenanga", latin: "Cananga odorata", essence: "The heady bloom", message: "Ylang-ylang is intoxicating in small amounts, overwhelming in excess. Something good in your life needs a smaller dose to stay good.", tend: "Reduce your exposure to one otherwise-good thing this week." },
  { id: "akar-manis", name: "Akar manis", latin: "Glycyrrhiza glabra", essence: "The harmonizer", message: "Licorice root is added to balance and round out other herbs, rarely the main note. Your role right now may be to harmonize a group, not to lead it.", tend: "Support someone else's idea fully today instead of pitching your own." },
  { id: "daun-katuk", name: "Daun katuk", latin: "Sauropus androgynus", essence: "The nourishing green", message: "Traditionally used to support new mothers' milk — pure nourishment for someone building something new. Give sustained, unglamorous support to someone starting out.", tend: "Check in on someone who's just begun something hard." },
  { id: "kayu-rapet", name: "Kayu rapet", latin: "Parameria laevigata", essence: "The tightener", message: "Used traditionally to firm and restore after strain. What in you has been stretched loose and needs deliberate restoration, not just rest?", tend: "Do one restorative practice with intention, not as an afterthought." },
  { id: "jahe-emprit", name: "Jahe emprit", latin: "Zingiber officinale var.", essence: "The small hot one", message: "Smaller and sharper than red ginger — a concentrated dose. A small, intense effort will outperform a long diffuse one this week.", tend: "Do one short, focused burst instead of a long half-hearted session." },
  { id: "daun-salam-koja", name: "Daun kari", latin: "Murraya koenigii", essence: "The distant memory", message: "Curry leaf carries a fragrance that lingers in memory long after the dish is gone. Something you do today will be remembered longer than you expect.", tend: "Do the thing worth being remembered for, not the thing that's merely urgent." },
  { id: "daun-mint2", name: "Daun kelor kering", latin: "Moringa oleifera (dried)", essence: "The preserved power", message: "Dried moringa keeps its nutrients concentrated long after the fresh leaf would wilt. What you learned in a hard season is still potent — don't discard it as 'old news.'", tend: "Reuse a lesson from a past hardship in today's decision." },
  { id: "daun-jambu-mete", name: "Daun jambu mete", latin: "Anacardium occidentale", essence: "The astringent hold", message: "Cashew leaf tightens and binds — used where things are too loose, too runny, too dispersed. Consolidate before you expand further.", tend: "Gather one scattered thing into a single place today." },
  { id: "buah-mengkudu", name: "Mengkudu", latin: "Morinda citrifolia", essence: "The pungent patience", message: "Noni fruit smells sharp and takes real patience to use — but its reputation for slow healing is old and consistent. Trust a slow remedy you'd normally dismiss for smelling wrong.", tend: "Give an unglamorous habit two more weeks before judging it." },
  { id: "kayu-siwak", name: "Siwak", latin: "Salvadora persica", essence: "The daily discipline", message: "A small stick, used daily, for centuries, for one clear purpose. Something in your life doesn't need reinventing — it needs consistent, humble repetition.", tend: "Repeat a small good habit today without trying to improve it." },
  { id: "daun-binahong", name: "Binahong", latin: "Anredera cordifolia", essence: "The wound closer", message: "Binahong leaf is pressed directly onto cuts to speed closing. Something in you is still open that could use direct, unhesitating attention rather than distraction.", tend: "Address the small open wound — literal or otherwise — today." },
  { id: "daun-sambung-nyawa", name: "Sambung nyawa", latin: "Gynura procumbens", essence: "The life-extender", message: "Its name literally means 'connecting life' — used for chronic, long-haul conditions. What you're managing right now is a marathon, not a crisis; pace accordingly.", tend: "Plan for the next month, not just the next day, on one issue." },
  { id: "daun-seledri", name: "Daun seledri", latin: "Apium graveolens", essence: "The pressure release", message: "Celery leaf is reached for to calm and lower — traditionally for blood pressure and tension. Something in your body or schedule is running too high; deliberately lower it.", tend: "Remove one source of pressure today instead of tolerating it." },
  { id: "kayu-manis-batang", name: "Kulit kayu manis", latin: "Cinnamomum verum (bark)", essence: "The layered warmth", message: "True cinnamon bark is made of many thin layers rolled together — strength through layering, not thickness. Build your resilience from several small supports, not one big one.", tend: "Add one more small support system instead of leaning harder on the one you have." },
  { id: "akar-kucing", name: "Akar kucing", latin: "Acalypha indica", essence: "The unassuming healer", message: "A common roadside plant, easy to overlook, long used in folk remedy. Someone unassuming near you has more to offer than their profile suggests.", tend: "Ask an overlooked person for their actual opinion today." },
  { id: "daun-tapak-liman", name: "Tapak liman", latin: "Elephantopus scaber", essence: "The grounded step", message: "Named for the elephant's footprint — heavy, deliberate, unhurried. Move slower and more deliberately through your next decision than feels natural.", tend: "Take twice as long as usual to decide one small thing today." },
  { id: "daun-ciplukan", name: "Ciplukan", latin: "Physalis angulata", essence: "The wrapped sweetness", message: "Ground cherry hides its sweetness inside a papery husk you have to open. Something good is available to you but requires you to unwrap it — ask, apply, reach out.", tend: "Make the ask you've been assuming would be refused." },
  { id: "daun-jarak", name: "Daun jarak", latin: "Ricinus communis", essence: "The drawing leaf", message: "Castor leaf is warmed and pressed on the belly to draw out discomfort. Something needs to be drawn out into the open rather than pressed further down.", tend: "Name the discomfort out loud to one trusted person." },
  { id: "daun-belimbing-wuluh", name: "Daun belimbing wuluh", latin: "Averrhoa bilimbi", essence: "The souring agent", message: "Sour starfruit leaf cuts richness and lowers what's swollen or excessive. Something in your life has gotten too rich, too much — trim it back.", tend: "Say no to one more thing than you normally would this week." },
  { id: "akar-wangi", name: "Akar wangi", latin: "Chrysopogon zizanioides", essence: "The deep-rooted calm", message: "Vetiver's roots run deeper than almost any other grass — its calm comes from what's unseen below. Your steadiness right now is coming from foundations no one else can see. Trust it.", tend: "Do something today that only your foundation, not your audience, would notice." },
  { id: "daun-bidara", name: "Daun bidara", latin: "Ziziphus mauritiana", essence: "The cleansing leaf", message: "Bidara leaf is used across traditions for cleansing and settling the spirit before rest. Before you take the next step, clear what's clinging from the last one.", tend: "Do one small closing ritual — a bath, a tidy room, a written goodbye — before starting something new." },
];

// 58-card deck. Pulls are random (see app/oracle/page.js), not
// tied to the calendar date — the deck doesn't repeat by design.

// Random pull — the deck doesn't repeat by calendar date on purpose.
// One pull per day is still enforced server-side (see /api/pulls).
// excludeId prevents the same card showing twice in a row, purely
// for a better felt sense of randomness (mathematically unnecessary,
// psychologically necessary).
export function randomCardIndex(excludeId = null) {
  if (!excludeId || DECK.length <= 1) return Math.floor(Math.random() * DECK.length);
  let idx = Math.floor(Math.random() * DECK.length);
  if (DECK[idx].id === excludeId) {
    idx = (idx + 1 + Math.floor(Math.random() * (DECK.length - 1))) % DECK.length;
  }
  return idx;
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/astro.js" << 'NISKALA_FILE_EOF'
// Personal layer: sun sign, shio, and the daily petung match
// between birth weton and today's weton.

import { getWeton } from "./javanese";
import { getPlanetaryHour } from "./planetary";
import { computeBazi, elementRelation, ELEMENT_NAME } from "./bazi";

const SIGNS = [
  { name: "Capricorn", from: [12, 22], element: "earth" },
  { name: "Aquarius", from: [1, 20], element: "air" },
  { name: "Pisces", from: [2, 19], element: "water" },
  { name: "Aries", from: [3, 21], element: "fire" },
  { name: "Taurus", from: [4, 20], element: "earth" },
  { name: "Gemini", from: [5, 21], element: "air" },
  { name: "Cancer", from: [6, 21], element: "water" },
  { name: "Leo", from: [7, 23], element: "fire" },
  { name: "Virgo", from: [8, 23], element: "earth" },
  { name: "Libra", from: [9, 23], element: "air" },
  { name: "Scorpio", from: [10, 23], element: "water" },
  { name: "Sagittarius", from: [11, 22], element: "fire" },
];

export function sunSign(date) {
  const md = (date.getMonth() + 1) * 100 + date.getDate();
  const ordered = SIGNS.filter((s) => s.name !== "Capricorn")
    .map((s) => ({ ...s, start: s.from[0] * 100 + s.from[1] }))
    .sort((a, b) => a.start - b.start);
  let match = SIGNS[0];
  for (const s of ordered) if (md >= s.start) match = s;
  if (md >= 1222) match = SIGNS[0];
  return match;
}

const SHIO = [
  "Monyet", "Ayam", "Anjing", "Babi", "Tikus", "Kerbau",
  "Macan", "Kelinci", "Naga", "Ular", "Kuda", "Kambing",
];

export function shio(date) {
  const year = date.getFullYear();
  const name = SHIO[year % 12];
  const boundary = date.getMonth() === 0 || (date.getMonth() === 1 && date.getDate() < 5);
  return { name, approximate: boundary };
}

const DAY_MEANING = {
  id: {
    Minggu: "matahari — visibilitas, energi yang ingin dilihat",
    Senin: "bulan — kepekaan, urusan rumah dan hati",
    Selasa: "api — dorongan, ketegasan, kadang tergesa",
    Rabu: "merkurial — bicara, pesan, transaksi kecil",
    Kamis: "guru/jupiter — perluasan, belajar, restu",
    Jumat: "venus — hubungan, keindahan, kesepakatan",
    Sabtu: "saturnus — batas, kedisiplinan, pekerjaan berat",
  },
  en: {
    Minggu: "sun — visibility, wanting to be seen",
    Senin: "moon — sensitivity, home and heart matters",
    Selasa: "fire — drive, sharpness, sometimes too fast",
    Rabu: "mercurial — talk, messages, small transactions",
    Kamis: "jupiter — expansion, learning, blessing",
    Jumat: "venus — relationships, beauty, agreements",
    Sabtu: "saturn — limits, discipline, heavy work",
  },
};

// Pancasuda: the birth neptu's permanent character reading —
// distinct from petungToday, which matches birth neptu against
// TODAY's neptu. This one never changes.
const PANCASUDA = [
  { key: "Sri", tone: "open",
    meaning: { id: "pembawa rezeki — orang mudah dekat sama kamu, dan kamu sering jadi sandaran tanpa diminta.",
      en: "fortune-bringer — people gravitate to you easily, and you end up being someone's support without asking for the role." } },
  { key: "Lungguh", tone: "open",
    meaning: { id: "berwibawa — kamu cocok mimpin, dan dihormati bahkan waktu nggak lagi nyari itu.",
      en: "authority — you're built to lead, and get respected even when you're not chasing it." } },
  { key: "Gedhong", tone: "open",
    meaning: { id: "penyimpan — kamu jago ngelola dan nabung, baik itu duit maupun rahasia orang.",
      en: "the vault — you're good at managing and saving, whether that's money or other people's secrets." } },
  { key: "Lara", tone: "guard",
    meaning: { id: "penuh uji — hidupmu sering ditempa lewat gesekan. Bukan kutukan, tapi juga bukan alasan buat terus-terusan nahan yang emang udah nggak sehat.",
      en: "tested — your life gets shaped through friction more than most. Not a curse, but also not a reason to keep tolerating what's genuinely unhealthy." } },
  { key: "Pati", tone: "close",
    meaning: { id: "penutup siklus — kamu sering jadi orang yang nyelesain apa yang orang lain tinggalin setengah jalan.",
      en: "the closer — you're often the one who finishes what other people leave half-done." } },
];

export function pancasudaBirth(birthNeptu) {
  return PANCASUDA[birthNeptu % 5];
}

const PETUNG = [
  { key: "Pati", tone: "close",
    meaning: { id: "penutupan — hari buat nyelesain, bukan mulai.", en: "closing — a day to finish things, not start them." } },
  { key: "Sri", tone: "open",
    meaning: { id: "rezeki ngalir — hari bagus buat mulai dan nawarin sesuatu.", en: "fortune flows — a good day to start something or make an offer." } },
  { key: "Lungguh", tone: "open",
    meaning: { id: "wibawa — hari bagus buat tampil, rapat, negosiasi.", en: "authority — a good day to show up, meet, negotiate." } },
  { key: "Dunya", tone: "open",
    meaning: { id: "keberuntungan materi — hari bagus buat transaksi.", en: "material luck — a good day for transactions." } },
  { key: "Lara", tone: "guard",
    meaning: { id: "gesekan — jaga energi, hindari konfrontasi.", en: "friction — guard your energy, avoid confrontation." } },
];

export function petungToday(birthNeptu, todayNeptu) {
  const r = (birthNeptu + todayNeptu) % 5;
  return PETUNG[r];
}

export function personalReading(birthDate, birthTimeStr, now = new Date()) {
  const birthWeton = getWeton(birthDate);
  const today = getWeton(now);
  const sign = sunSign(birthDate);
  const zodiacShio = shio(birthDate);

  let birthHour = null;
  if (birthTimeStr) {
    const [h, m] = birthTimeStr.split(":").map(Number);
    if (!Number.isNaN(h)) {
      const bd = new Date(birthDate);
      bd.setHours(h, m || 0);
      birthHour = getPlanetaryHour(bd);
    }
  }

  const petung = petungToday(birthWeton.neptu, today.neptu);
  const isWetonDay =
    birthWeton.day === today.day && birthWeton.pasaran === today.pasaran;
  const pancasuda = pancasudaBirth(birthWeton.neptu);

  let bazi = null;
  let baziToday = null;
  let dayMasterRelationToday = null;
  try {
    bazi = computeBazi(birthDate, birthTimeStr);
    baziToday = computeBazi(now, null);
    dayMasterRelationToday = elementRelation(
      baziToday.day.stemElement,
      bazi.dayMaster.element
    );
  } catch {
    bazi = null;
  }

  return {
    birthWeton, today, sign, shio: zodiacShio, birthHour, petung, isWetonDay,
    pancasuda, bazi, baziToday, dayMasterRelationToday,
  };
}

export { DAY_MEANING };

export function dosAndDonts(reading, moon, hour, lang = "id") {
  const dos = [];
  const donts = [];
  const { petung, isWetonDay, sign, birthWeton, today } = reading;
  const t = (id, en) => (lang === "en" ? en : id);

  if (isWetonDay) {
    dos.push(t(
      "Hari wetonmu, selapanan — tradisinya: puasa, laku prihatin, atau sekadar melambat.",
      "Your weton day — tradition says: fast, sit still, or just slow down."
    ));
    donts.push(t("Jangan jejalin hal berat hari ini kalau bisa dihindari.", "Don't cram in anything heavy today if you can help it."));
  }

  const pm = petung.meaning[lang === "en" ? "en" : "id"];
  if (petung.tone === "open") {
    dos.push(`${t("Petung", "Today's petung is")} ${petung.key}: ${pm}`);
  } else if (petung.tone === "guard") {
    donts.push(`${t("Petung", "Today's petung is")} ${petung.key}: ${pm}`);
    dos.push(t("Prioritaskan istirahat dan urusan ringan.", "Prioritize rest and light matters."));
  } else {
    donts.push(`${t("Petung", "Today's petung is")} ${petung.key}: ${pm}`);
    dos.push(t("Tutup urusan yang menggantung — hari bagus buat beres-beres.", "Close out loose ends — good day for tidying up."));
  }

  if (moon.fraction <= 0.5) {
    dos.push(t("Bulan lagi tumbuh — tanam, mulai, kirim.", "Moon's waxing — plant, start, send."));
  } else {
    dos.push(t("Bulan lagi susut — lepasin, rapiin, selesaiin.", "Moon's waning — release, tidy, finish."));
    donts.push(t("Jangan luncurin hal besar deket bulan mati.", "Don't launch anything big this close to the new moon."));
  }

  const fireDays = ["Mars", "Sun"];
  if (fireDays.includes(hour.dayRuler) && sign.element === "fire") {
    dos.push(t(
      `Hari ${hour.dayRuler} nyambung sama elemen apimu (${sign.name}) — pakai buat yang butuh nyali.`,
      `${hour.dayRuler}'s day lines up with your fire sign (${sign.name}) — use it for the thing that takes nerve.`
    ));
  }
  if (hour.dayRuler === "Moon" && sign.element === "water") {
    dos.push(t(
      `Hari Bulan nyambung sama elemen airmu (${sign.name}) — obrolan jujur bakal ngalir sendiri.`,
      `Moon's day lines up with your water sign (${sign.name}) — honest conversation flows easier.`
    ));
  }

  if (today.isKliwon) {
    dos.push(t("Kliwon: catat sinkronisitas dan mimpi, lalu lintas isyarat lagi ramai.", "Kliwon: log your synchronicities and dreams — the signal traffic is heavier today."));
  }

  if (birthWeton.pasaran === today.pasaran && !isWetonDay) {
    dos.push(t(
      `Pasaran hari ini sama kayak pasaran lahirmu (${today.pasaran}) — hari yang akrab, intuisi lebih tajam.`,
      `Today's market-day matches your birth market-day (${today.pasaran}) — a familiar day, sharper intuition.`
    ));
  }

  if (reading.dayMasterRelationToday && reading.bazi) {
    const dm = ELEMENT_NAME[lang === "en" ? "en" : "id"][reading.bazi.dayMaster.element];
    const rel = reading.dayMasterRelationToday;
    if (rel === "produces")
      dos.push(t(`Elemen hari ini nyalain day master-mu (${dm}) — energi ngalir keluar gampang, bagus buat berkarya.`,
        `Today's element feeds your day master (${dm}) — energy flows out easily, good for making things.`));
    else if (rel === "produced_by")
      dos.push(t(`Hari ini "ngasih makan" day master-mu (${dm}) — waktu yang pas buat nerima, belajar, isi ulang.`,
        `Today "feeds" your day master (${dm}) — a good time to receive, learn, recharge.`));
    else if (rel === "controls")
      donts.push(t(`Elemen hari ini nekan day master-mu (${dm}) — kurangi ambisi besar, jaga energi.`,
        `Today's element presses on your day master (${dm}) — dial back big ambitions, guard your energy.`));
    else if (rel === "controlled_by")
      dos.push(t(`Day master-mu (${dm}) lagi unggul atas elemen hari ini — momentum di tanganmu, ambil inisiatif.`,
        `Your day master (${dm}) has the upper hand today — momentum is yours, take initiative.`));
    else if (rel === "same")
      dos.push(t(`Elemen hari ini sewarna sama day master-mu (${dm}) — keputusan bakal kerasa lebih jelas.`,
        `Today's element matches your day master (${dm}) — decisions will feel clearer.`));
  }

  return { dos: dos.slice(0, 5), donts: donts.slice(0, 4) };
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/auth.js" << 'NISKALA_FILE_EOF'
import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";

const COOKIE = "niskala_session";
const secret = () =>
  new TextEncoder().encode(process.env.AUTH_SECRET || "dev-secret-change-me");

export async function createSession(userId) {
  const token = await new SignJWT({ sub: String(userId) })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(secret());
  cookies().set(COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    maxAge: 60 * 60 * 24 * 30,
    path: "/",
  });
}

export async function getUserId() {
  const token = cookies().get(COOKIE)?.value;
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, secret());
    return payload.sub ? Number(payload.sub) : null;
  } catch {
    return null;
  }
}

export function clearSession() {
  cookies().delete(COOKIE);
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/bazi.js" << 'NISKALA_FILE_EOF'
// Four Pillars (Bazi) — approximate but formula-verified.
// Day pillar: exact, via Julian Day Number (T = 1+mod(JDN-1,10),
// B = 1+mod(JDN+1,12) — the standard sexagenary day formula).
// Year pillar: uses Li Chun (~Feb 4) as the year boundary, the
// convention Bazi uses (not Chinese New Year). Off by a day in some
// years since Li Chun isn't fixed to the 4th exactly.
// Month pillar: uses approximate solar-term month boundaries (each
// within ~1 day of the true date). Hour pillar: exact given the
// stated hour, using the standard day-stem-to-hour-stem formula.
// This is a reflective approximation, not a professional chart —
// say so in the UI.

import { julianDayNumber } from "./javanese";

const STEMS = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"];
const STEM_PINYIN = ["Jia", "Yi", "Bing", "Ding", "Wu", "Ji", "Geng", "Xin", "Ren", "Gui"];
const STEM_ELEMENT = ["wood", "wood", "fire", "fire", "earth", "earth", "metal", "metal", "water", "water"];
const STEM_POLARITY = ["yang", "yin", "yang", "yin", "yang", "yin", "yang", "yin", "yang", "yin"];

const BRANCHES = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"];
const BRANCH_PINYIN = ["Zi", "Chou", "Yin", "Mao", "Chen", "Si", "Wu", "Wei", "Shen", "You", "Xu", "Hai"];
const BRANCH_ANIMAL = ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"];
const BRANCH_ELEMENT = ["water", "earth", "wood", "wood", "earth", "fire", "fire", "earth", "metal", "metal", "earth", "water"];

const ELEMENT_NAME = {
  id: { wood: "Kayu", fire: "Api", earth: "Tanah", metal: "Logam", water: "Air" },
  en: { wood: "Wood", fire: "Fire", earth: "Earth", metal: "Metal", water: "Water" },
};
const ELEMENT_TRAIT = {
  id: {
    wood: "tumbuh, fleksibel, cari arah — energi perintis",
    fire: "menyala, kelihatan, cepat nyebar — energi ekspresif",
    earth: "stabil, nampung, nyambungin — energi penopang",
    metal: "tajam, terstruktur, presisi — energi penegas",
    water: "ngalir, dalam, adaptif — energi perenung",
  },
  en: {
    wood: "growing, flexible, direction-seeking — pioneer energy",
    fire: "burning, visible, quick to spread — expressive energy",
    earth: "stable, containing, connecting — supporting energy",
    metal: "sharp, structured, precise — decisive energy",
    water: "flowing, deep, adaptive — reflective energy",
  },
};

function pillar(stemIndex0, branchIndex0) {
  const s = ((stemIndex0 % 10) + 10) % 10;
  const b = ((branchIndex0 % 12) + 12) % 12;
  return {
    stem: STEMS[s],
    stemPinyin: STEM_PINYIN[s],
    stemElement: STEM_ELEMENT[s],
    stemPolarity: STEM_POLARITY[s],
    branch: BRANCHES[b],
    branchPinyin: BRANCH_PINYIN[b],
    branchAnimal: BRANCH_ANIMAL[b],
    branchElement: BRANCH_ELEMENT[b],
    label: `${STEM_PINYIN[s]} ${BRANCH_PINYIN[b]}`,
    hanzi: `${STEMS[s]}${BRANCHES[b]}`,
  };
}

// Approximate solar-term month boundaries (month, day) -> branch index0 (Yin=2)
const MONTH_BOUNDS = [
  { after: [1, 5], branch: 1 },   // Chou:  Jan 6 – Feb 3
  { after: [2, 3], branch: 2 },   // Yin:   Feb 4 – Mar 5
  { after: [3, 5], branch: 3 },   // Mao:   Mar 6 – Apr 4
  { after: [4, 4], branch: 4 },   // Chen:  Apr 5 – May 5
  { after: [5, 5], branch: 5 },   // Si:    May 6 – Jun 5
  { after: [6, 5], branch: 6 },   // Wu:    Jun 6 – Jul 6
  { after: [7, 6], branch: 7 },   // Wei:   Jul 7 – Aug 7
  { after: [8, 7], branch: 8 },   // Shen:  Aug 8 – Sep 7
  { after: [9, 7], branch: 9 },   // You:   Sep 8 – Oct 7
  { after: [10, 7], branch: 10 }, // Xu:    Oct 8 – Nov 6
  { after: [11, 6], branch: 11 }, // Hai:   Nov 7 – Dec 6
  { after: [12, 6], branch: 0 },  // Zi:    Dec 7 – Jan 5
];

function monthBranchIndex0(date) {
  const m = date.getMonth() + 1;
  const d = date.getDate();
  let branch = 1; // default Chou (covers early Jan before Jan 6 -> handled below)
  if (m === 1 && d < 6) return 0; // Zi carries from prior December
  for (const b of MONTH_BOUNDS) {
    const [bm, bd] = b.after;
    if (m > bm || (m === bm && d > bd)) branch = b.branch;
  }
  return branch;
}

// Yin-month stem base, by year-stem group (year stem index0)
const YIN_BASE_BY_YEARSTEM_MOD5 = {
  0: 2, // Jia/Ji  -> Bing (index0 2)
  1: 4, // Yi/Geng -> Wu   (index0 4)
  2: 6, // Bing/Xin-> Geng (index0 6)
  3: 8, // Ding/Ren-> Ren  (index0 8)
  4: 0, // Wu/Gui  -> Jia  (index0 0)
};

function baziYear(date) {
  const m = date.getMonth() + 1;
  const d = date.getDate();
  const afterLiChun = m > 2 || (m === 2 && d >= 4);
  return afterLiChun ? date.getFullYear() : date.getFullYear() - 1;
}

function yearPillar(date) {
  const y = baziYear(date);
  const stemIndex0 = ((y + 6) % 10 + 10) % 10;
  const branchIndex0 = ((y + 8) % 12 + 12) % 12;
  return pillar(stemIndex0, branchIndex0);
}

function monthPillar(date, yearStemIndex0) {
  const branchIndex0 = monthBranchIndex0(date);
  // distance from Yin (index0=2) going forward through the fixed order
  const YIN_ORDER = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 1]; // Yin..Chou
  const monthIndexFromYin = YIN_ORDER.indexOf(branchIndex0);
  const yinBase = YIN_BASE_BY_YEARSTEM_MOD5[yearStemIndex0 % 5];
  const stemIndex0 = (yinBase + monthIndexFromYin) % 10;
  return pillar(stemIndex0, branchIndex0);
}

function dayPillar(date) {
  const jdn = julianDayNumber(date);
  const stemIndex0 = ((jdn - 1) % 10 + 10) % 10; // T = 1+mod(JDN-1,10), 0-based here
  const branchIndex0 = ((jdn + 1) % 12 + 12) % 12; // B = 1+mod(JDN+1,12), 0-based here
  return pillar(stemIndex0, branchIndex0);
}

function hourPillar(date, hour, minute, dayStemIndex0) {
  // Hours 23:00–23:59 belong to the next day's Zi hour in tradition.
  let branchIndex0;
  if (hour === 23) branchIndex0 = 0;
  else branchIndex0 = Math.floor(((hour + 1) % 24) / 2);
  const stemIndex0 = (dayStemIndex0 * 2 + branchIndex0) % 10;
  return pillar(stemIndex0, branchIndex0);
}

export function computeBazi(birthDate, birthTimeStr) {
  const yp = yearPillar(birthDate);
  const yearStemIndex0 = STEM_PINYIN.indexOf(yp.stemPinyin);
  const mp = monthPillar(birthDate, yearStemIndex0);
  const dp = dayPillar(birthDate);
  const dayStemIndex0 = STEM_PINYIN.indexOf(dp.stemPinyin);

  let hp = null;
  if (birthTimeStr) {
    const [h, m] = birthTimeStr.split(":").map(Number);
    if (!Number.isNaN(h)) hp = hourPillar(birthDate, h, m || 0, dayStemIndex0);
  }

  const pillars = [yp, mp, dp, ...(hp ? [hp] : [])];
  const elementCounts = { wood: 0, fire: 0, earth: 0, metal: 0, water: 0 };
  pillars.forEach((p) => {
    elementCounts[p.stemElement]++;
    elementCounts[p.branchElement]++;
  });

  const sorted = Object.entries(elementCounts).sort((a, b) => b[1] - a[1]);
  const dominant = sorted[0][0];
  const lacking = sorted.filter(([, n]) => n === 0).map(([k]) => k);

  return {
    year: yp,
    month: mp,
    day: dp,
    hour: hp,
    dayMaster: { element: dp.stemElement, polarity: dp.stemPolarity, stem: dp.stemPinyin },
    elementCounts,
    dominant,
    lacking,
    approximate: true,
  };
}

export { ELEMENT_NAME, ELEMENT_TRAIT };

const PRODUCES = { wood: "fire", fire: "earth", earth: "metal", metal: "water", water: "wood" };
const CONTROLS = { wood: "earth", earth: "water", water: "fire", fire: "metal", metal: "wood" };

export function elementRelation(from, to) {
  if (from === to) return "same";
  if (PRODUCES[from] === to) return "produces";
  if (PRODUCES[to] === from) return "produced_by";
  if (CONTROLS[from] === to) return "controls";
  if (CONTROLS[to] === from) return "controlled_by";
  return "neutral";
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/i18n.js" << 'NISKALA_FILE_EOF'
"use client";

import { createContext, useContext, useEffect, useState } from "react";

const LANG_KEY = "niskala.lang";

const UI = {
  id: {
    nav_today: "Hari ini", nav_dreams: "Mimpi", nav_oracle: "Orakel", nav_you: "Kamu",
    home_eyebrow: "Hari ini",
    home_personal_title: "Pembacaan personal",
    home_personal_body: "Masuk dengan data lahirmu untuk melihat pembacaan hari ini yang benar-benar dihitung dari lahirmu — bukan ramalan umum.",
    login_or_signup: "Masuk / daftar",
    weton_day_label: "Hari ini weton-mu.",
    section_growth: "Yang diuji hari ini",
    section_connection: "Relasi hari ini",
    section_energy: "Energi & tubuh",
    section_decisions: "Kerja & keputusan",
    section_intuition: "Intuisi & spiritual",
    do_label: "Lakukan",
    dont_label: "Hindari",
    show_detail: "Lihat detail teknis (weton, bazi, jam planetari)",
    hide_detail: "Sembunyikan detail teknis",
    detail_petung: "Petung hari ini",
    detail_bazi_today: "Bazi hari ini",
    detail_day_pillar: "Pilar hari",
    detail_day_master: "Day master lahirmu",
    detail_element_today: "Elemen hari ini",
    detail_relation: "Hubungan",
    detail_transit: "Transit planetari",
    detail_ruled_by: "Hari ini diampu",
    detail_now: "Sekarang",
    detail_next: "Berikutnya",
    detail_next_hours: "4 jam ke depan",

    profile_title: "Profil energetik",
    profile_not_logged_in: "Kamu belum masuk.",
    profile_born: "Lahir",
    section_weton: "Weton", weton_sub: "Kalender Jawa — hari dan pasaran kelahiranmu",
    weton_howto: "Cara baca:",
    weton_howto_body: "tiap hari punya nilai (Minggu 5 – Sabtu 9), tiap pasaran juga punya nilai (Legi 5 – Kliwon 8). Dijumlahkan jadi neptu — angka watak dasarmu, dipakai untuk menghitung kecocokan dengan hari-hari lain, termasuk hari ini di beranda.",
    kliwon_note: "Lahir di hari Kliwon — secara tradisi dianggap punya kepekaan lebih terhadap hal-hal halus.",
    pancasuda_title: "Pancasuda — watak permanen",
    pancasuda_note: "Ini berbeda dari pembacaan harian di beranda — pancasuda adalah watak dasar dari neptu lahirmu, tidak berubah setiap hari.",
    section_bazi: "Bazi — Empat Pilar",
    bazi_sub_prefix: "Sistem astrologi Tiongkok berbasis elemen. Perhitungan pendekatan",
    bazi_sub_no_hour: " (jam lahir belum diisi, pilar jam belum dihitung)",
    bazi_sub_suffix: "— untuk chart presisi penuh, konsultasikan dengan ahli Bazi.",
    bazi_howto: "Cara baca:",
    bazi_howto_body: "setiap pilar (Tahun/Bulan/Hari/Jam) punya satu batang langit (stem) dan satu cabang bumi (branch) — gabungan keduanya menentukan elemen dan shio pilar itu. Day master selalu diambil dari batang langit pilar Hari — ini \"elemen inti\"-mu, cara kamu secara default merespons dunia. Pilar lain (tahun, bulan, jam) adalah konteks di sekitarnya: tahun = warisan keluarga/generasi, bulan = lingkungan masa kecil dan karier, jam = bagaimana orang lain melihatmu.",
    bazi_daymaster_prefix: "Day master-mu adalah",
    bazi_elements_title: "Keseimbangan elemen",
    bazi_elements_sub: (n) => `Dari ${n} karakter pilar${n === "8" ? " (termasuk jam)" : " (belum termasuk jam)"} — semakin banyak satu elemen muncul, semakin dominan sifatnya dalam wataknmu.`,
    bazi_dominant_prefix: "Elemen dominan:",
    bazi_lacking_prefix: "Tidak muncul sama sekali:",
    bazi_lacking_note: "dalam bacaan Bazi, elemen yang absen kadang justru yang paling dicari sepanjang hidup, dan area yang paling perlu diusahakan secara sadar (bukan datang otomatis).",
    section_conclusion: "Kesimpulan — no sugarcoat",
    conclusion_sub: "Dibaca dari pancasuda dan keseimbangan elemen bazi-mu. Ini watak dasar, bukan ramalan hari ini — dan bukan pengganti nasihat profesional untuk hal yang benar-benar serius.",
    love: "Cinta", career: "Karier", health: "Kesehatan",
    section_zodiac: "Zodiak & shio",
    imlek_note: "Lahir dekat pergantian Imlek — shio-mu bisa jadi tahun sebelumnya, cek tanggal Imlek tahun lahirmu untuk kepastian.",
    section_planetary: "Jam planetari",
    planetary_sub: "Urutan Chaldean, disederhanakan untuk garis khatulistiwa",
    birth_hour_note: "Ini lapisan energi tambahan di luar weton dan bazi-mu, dari posisi planet saat kamu lahir.",
    born_at_hour: "Kamu lahir di jam",
    schedule_title: "Jadwal hari ini",
    schedule_sub: "Geser untuk melihat jam-jam lainnya",
    logout: "Keluar",

    dreams_title: "Mimpi", dreams_eyebrow: "Jurnal mimpi",
    dreams_sub: "Catat sebelum menguap. Tafsir belakangan.",
    dreams_need_login: "Masuk dulu supaya mimpimu tersimpan dan bisa dibuka dari mana saja.",
    dreams_log_button: "Catat mimpi semalam",
    dreams_placeholder: "Semalam mimpi apa? Tulis apa adanya, bahasa campur juga boleh…",
    dreams_save: "Simpan mimpi", dreams_saving: "Menyimpan…", dreams_cancel: "Batal",
    dreams_empty: "Belum ada mimpi. Arsipmu dimulai besok pagi.",
    dreams_interpreted: "sudah ditafsir",
    dream_detail_title: "Mimpinya",
    dream_interpret_button: "Tafsir lewat tiga lensa",
    dream_reinterpret_button: "Tafsir ulang (pakai bahasa yang lagi aktif)",
    dream_interpreting: "Membaca lapisan…",
    dream_consulting: "Berkonsultasi dengan Jung, primbon, dan Ibn Sirin — bisa sampai 20 detik buat tafsir yang dalam…",
    dream_no_symbols: "Tidak ada simbol yang cocok di leksikon offline, dan layanan tafsir belum dikonfigurasi. Tambahkan ANTHROPIC_API_KEY untuk tafsir penuh — atau tulis mimpinya lebih detail.",
    dream_overall_title: "Kesimpulan keseluruhan",
    dream_questions_title: "Buat direnungin",
    dream_lenses_title: "Tiga lensa",
    dream_lenses_sub: "Sudut pandang berbeda dari mimpi yang sama — bukan tiga tafsir terpisah.",
    dream_source_claude: "Tafsir dibuat khusus untuk mimpi ini.",
    dream_source_lexicon: "Tafsir dari leksikon bawaan — tambahkan API key untuk tafsir yang spesifik.",
    dream_source_generic: "Nggak ada simbol spesifik yang cocok, jadi ini tafsir umum berdasarkan mood-mu — tambahin detail lebih di mimpimu buat tafsir yang lebih spesifik lain kali.",
    dream_source_suffix: "Tiap tradisi memang berbeda; ambil yang beresonansi.",
    dream_not_found: "Mimpi tidak ditemukan", back: "Kembali",
    login_first: "Masuk dulu", to_login: "Ke halaman masuk",

    oracle_title: "Orakel", oracle_eyebrow: "Orakel botani",
    oracle_sub: "Satu kartu sehari, ditarik acak dari 58 botani. Benar-benar acak — dek ini tidak mengulang pola per tanggal.",
    oracle_need_login: "Masuk dulu supaya kartu harianmu dan benang merahnya tersimpan.",
    oracle_shuffled: "Dek sudah dikocok untuk hari ini",
    oracle_58: "Lima puluh delapan botani. Satu akan bicara.",
    oracle_pull_button: "Tarik kartu hari ini",
    oracle_already: "Kamu sudah menarik kartu hari ini.",
    oracle_fail: "Gagal menarik kartu — coba lagi.",
    oracle_tend: "Rawat:",
    oracle_threads: "Benang merah",
    oracle_thread_returning: "terus kembali —",
    oracle_thread_season: "sedang jadi pelajaran musim ini.",
    oracle_history: "Tarikan sebelumnya",

    login_title: "Masuk", signup_title: "Daftar",
    login_sub: "Lanjutkan membaca yang tak terlihat.",
    signup_sub: "Data lahirmu dipakai menghitung weton, zodiak, dan pembacaan harianmu.",
    email: "Email", password: "Password", password_min: "Minimal 8 karakter",
    name_optional: "Nama panggilan", name_placeholder: "Opsional",
    birth_date: "Tanggal lahir", birth_time: "Jam lahir",
    birth_time_note: "Nggak tahu persis? Kosongkan saja — perkiraan pun membantu.",
    birth_place: "Tempat lahir", birth_place_placeholder: "mis. Tangerang",
    submit_login: "Masuk", submit_signup: "Daftar", submitting: "Sebentar…",
    no_account: "Belum punya akun", have_account: "Sudah punya akun",
    forgot_password: "Lupa password?",
    forgot_title: "Reset password",
    forgot_sub: "Masukkan email-mu, kami kirim link buat atur password baru.",
    forgot_sent: "Kalau email itu terdaftar, kami udah kirim link reset ke sana. Cek inbox (dan folder spam) — link berlaku 1 jam.",
    reset_no_token: "Link ini nggak lengkap atau nggak valid. Minta link reset baru dari halaman masuk.",
    reset_set_new: "Atur password baru buat akunmu.",
    new_password: "Password baru",
    submit_reset: "Reset password",
    submit_forgot: "Kirim link reset",
    reset_success: "Password berhasil diganti. Silakan masuk pakai password baru.",
    back_to_login: "Kembali ke halaman masuk",
    show_password: "Tampilkan password",
    hide_password: "Sembunyikan password",
  },
  en: {
    nav_today: "Today", nav_dreams: "Dreams", nav_oracle: "Oracle", nav_you: "You",
    home_eyebrow: "Today",
    home_personal_title: "Personal reading",
    home_personal_body: "Sign in with your birth details to see today's reading actually calculated from your birth data — not a generic forecast.",
    login_or_signup: "Sign in / sign up",
    weton_day_label: "Today is your weton day.",
    section_growth: "What's being tested today",
    section_connection: "Today's connections",
    section_energy: "Energy & body",
    section_decisions: "Work & decisions",
    section_intuition: "Intuition & spirit",
    do_label: "Do",
    dont_label: "Avoid",
    show_detail: "Show technical detail (weton, bazi, planetary hours)",
    hide_detail: "Hide technical detail",
    detail_petung: "Today's petung",
    detail_bazi_today: "Today's bazi",
    detail_day_pillar: "Day pillar",
    detail_day_master: "Your day master",
    detail_element_today: "Today's element",
    detail_relation: "Relation",
    detail_transit: "Planetary transit",
    detail_ruled_by: "Today is ruled by",
    detail_now: "Now",
    detail_next: "Next",
    detail_next_hours: "Next 4 hours",

    profile_title: "Energetic profile",
    profile_not_logged_in: "You're not signed in.",
    profile_born: "Born",
    section_weton: "Weton", weton_sub: "Javanese calendar — your day and market-week of birth",
    weton_howto: "How to read it:",
    weton_howto_body: "each day carries a value (Sunday 5 – Saturday 9), each of the five market-days carries one too (Legi 5 – Kliwon 8). Summed, they make your neptu — your baseline character number, used to compute compatibility with other days, including today on the home screen.",
    kliwon_note: "Born on a Kliwon day — traditionally considered more attuned to subtle things.",
    pancasuda_title: "Pancasuda — your permanent temperament",
    pancasuda_note: "This differs from the daily reading on the home screen — pancasuda is the baseline character of your birth neptu, and it never changes.",
    section_bazi: "Bazi — Four Pillars",
    bazi_sub_prefix: "A Chinese element-based astrology system. Approximate calculation",
    bazi_sub_no_hour: " (birth time not provided, hour pillar not calculated)",
    bazi_sub_suffix: "— for a fully precise chart, consult a Bazi practitioner.",
    bazi_howto: "How to read it:",
    bazi_howto_body: "each pillar (Year/Month/Day/Hour) carries one heavenly stem and one earthly branch — together they determine that pillar's element and animal. Your day master is always taken from the Day pillar's stem — it's your \"core element,\" how you default to responding to the world. The other pillars are context around it: year = family/generational inheritance, month = childhood environment and career, hour = how others tend to see you.",
    bazi_daymaster_prefix: "Your day master is",
    bazi_elements_title: "Element balance",
    bazi_elements_sub: (n) => `From ${n} pillar characters${n === "8" ? " (including hour)" : " (not yet including hour)"} — the more an element appears, the more it shapes your temperament.`,
    bazi_dominant_prefix: "Dominant element:",
    bazi_lacking_prefix: "Completely absent:",
    bazi_lacking_note: "in Bazi reading, an absent element is often the one most sought after throughout life — the area that needs deliberate effort rather than coming naturally.",
    section_conclusion: "The bottom line — no sugarcoating",
    conclusion_sub: "Read from your pancasuda and bazi element balance. This is baseline temperament, not a forecast for today — and not a substitute for professional advice on anything genuinely serious.",
    love: "Love", career: "Career", health: "Health",
    section_zodiac: "Zodiac & Chinese sign",
    imlek_note: "Born close to Lunar New Year — your Chinese zodiac sign might actually be the previous year's; check the exact Lunar New Year date for your birth year to be sure.",
    section_planetary: "Planetary hours",
    planetary_sub: "Chaldean order, simplified for equatorial latitudes",
    birth_hour_note: "This is an extra layer beyond your weton and bazi, drawn from planetary position at the moment you were born.",
    born_at_hour: "You were born in the hour of",
    schedule_title: "Today's schedule",
    schedule_sub: "Scroll to see the other hours",
    logout: "Sign out",

    dreams_title: "Dreams", dreams_eyebrow: "Dream journal",
    dreams_sub: "Log it before it fades. Interpret later.",
    dreams_need_login: "Sign in first so your dreams save and can be opened from anywhere.",
    dreams_log_button: "Log last night's dream",
    dreams_placeholder: "What did you dream about? Write it as it came, mixed languages are fine too…",
    dreams_save: "Save dream", dreams_saving: "Saving…", dreams_cancel: "Cancel",
    dreams_empty: "No dreams yet. Your archive starts tomorrow morning.",
    dreams_interpreted: "interpreted",
    dream_detail_title: "The dream",
    dream_interpret_button: "Interpret through three lenses",
    dream_reinterpret_button: "Interpret again (using current language)",
    dream_interpreting: "Reading the layers…",
    dream_consulting: "Consulting Jung, primbon, and Ibn Sirin — can take up to 20s for a deep reading…",
    dream_no_symbols: "No symbols matched in the offline lexicon, and the interpretation service isn't configured. Add an ANTHROPIC_API_KEY to unlock full readings — or add more detail to the dream text.",
    dream_overall_title: "Overall reading",
    dream_questions_title: "Worth sitting with",
    dream_lenses_title: "Three lenses",
    dream_lenses_sub: "Different angles on the same dream — not three separate readings.",
    dream_source_claude: "This reading was generated specifically for this dream.",
    dream_source_lexicon: "Reading from the built-in lexicon — add an API key for dream-specific interpretation.",
    dream_source_generic: "No specific symbol matched, so this is a general reading based on your mood — add more detail to your dream for a more specific one next time.",
    dream_source_suffix: "The traditions genuinely differ; take what resonates.",
    dream_not_found: "Dream not found", back: "Back",
    login_first: "Sign in first", to_login: "Go to sign in",

    oracle_title: "Oracle", oracle_eyebrow: "Botanical oracle",
    oracle_sub: "One card a day, drawn at random from 58 botanicals. Genuinely random — the deck doesn't repeat by date.",
    oracle_need_login: "Sign in first so your daily card and its threads get saved.",
    oracle_shuffled: "The deck is shuffled for today",
    oracle_58: "Fifty-eight botanicals. One will speak.",
    oracle_pull_button: "Draw today's card",
    oracle_already: "You've already drawn today's card.",
    oracle_fail: "Failed to draw a card — try again.",
    oracle_tend: "Tend:",
    oracle_threads: "Threads",
    oracle_thread_returning: "keeps returning —",
    oracle_thread_season: "is this season's lesson.",
    oracle_history: "Past draws",

    login_title: "Sign in", signup_title: "Sign up",
    login_sub: "Continue reading the unseen.",
    signup_sub: "Your birth details are used to calculate your weton, zodiac, and daily readings.",
    email: "Email", password: "Password", password_min: "At least 8 characters",
    name_optional: "Nickname", name_placeholder: "Optional",
    birth_date: "Birth date", birth_time: "Birth time",
    birth_time_note: "Not sure exactly? Leave it blank — a rough estimate still helps.",
    birth_place: "Birthplace", birth_place_placeholder: "e.g. Tangerang",
    submit_login: "Sign in", submit_signup: "Sign up", submitting: "One sec…",
    no_account: "Don't have an account", have_account: "Already have an account",
    forgot_password: "Forgot password?",
    forgot_title: "Reset password",
    forgot_sub: "Enter your email and we'll send a link to set a new password.",
    forgot_sent: "If that email is registered, we've sent a reset link to it. Check your inbox (and spam folder) — the link is valid for 1 hour.",
    reset_no_token: "This link is incomplete or invalid. Request a new reset link from the sign-in page.",
    reset_set_new: "Set a new password for your account.",
    new_password: "New password",
    submit_reset: "Reset password",
    submit_forgot: "Send reset link",
    reset_success: "Password changed successfully. Please sign in with your new password.",
    back_to_login: "Back to sign in",
    show_password: "Show password",
    hide_password: "Hide password",
  },
};

const LanguageContext = createContext({ lang: "id", setLang: () => {}, t: (k) => k });

export function LanguageProvider({ children }) {
  const [lang, setLangState] = useState("en");
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const saved = typeof window !== "undefined" ? window.localStorage.getItem(LANG_KEY) : null;
    if (saved === "id" || saved === "en") setLangState(saved);
    setReady(true);
  }, []);

  function setLang(next) {
    setLangState(next);
    if (typeof window !== "undefined") window.localStorage.setItem(LANG_KEY, next);
  }

  function t(key, ...args) {
    const dict = UI[lang] || UI.id;
    const val = dict[key];
    if (typeof val === "function") return val(...args);
    return val ?? key;
  }

  if (!ready) return null;

  return (
    <LanguageContext.Provider value={{ lang, setLang, t }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  return useContext(LanguageContext);
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/javanese.js" << 'NISKALA_FILE_EOF'
// Javanese weton: 7-day week x 5-day pasaran cycle.
// Pasaran derived from Julian Day Number mod 5.
// Verified anchor: 17 Aug 1945 = Jumat Legi.

const PASARAN = ["Legi", "Pahing", "Pon", "Wage", "Kliwon"];
const PASARAN_NEPTU = { Legi: 5, Pahing: 9, Pon: 7, Wage: 4, Kliwon: 8 };

const DAYS = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
const DAY_NEPTU = {
  Minggu: 5, Senin: 4, Selasa: 3, Rabu: 7, Kamis: 8, Jumat: 6, Sabtu: 9,
};

const PASARAN_MEANING = {
  Legi: "sweet beginnings, openness, east wind",
  Pahing: "intensity, ambition, holding fire",
  Pon: "visibility, expression, standing in light",
  Wage: "stillness, guardedness, deep roots",
  Kliwon: "the threshold day, spirit traffic, heightened intuition",
};

export function julianDayNumber(date) {
  const y = date.getFullYear();
  const m = date.getMonth() + 1;
  const d = date.getDate();
  const a = Math.floor((14 - m) / 12);
  const yy = y + 4800 - a;
  const mm = m + 12 * a - 3;
  return (
    d +
    Math.floor((153 * mm + 2) / 5) +
    365 * yy +
    Math.floor(yy / 4) -
    Math.floor(yy / 100) +
    Math.floor(yy / 400) -
    32045
  );
}

export function getWeton(date = new Date()) {
  const jdn = julianDayNumber(date);
  const pasaran = PASARAN[jdn % 5];
  const day = DAYS[date.getDay()];
  const neptu = DAY_NEPTU[day] + PASARAN_NEPTU[pasaran];
  return {
    day,
    pasaran,
    label: `${day} ${pasaran}`,
    neptu,
    meaning: PASARAN_MEANING[pasaran],
    isKliwon: pasaran === "Kliwon",
  };
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/lexicon.js" << 'NISKALA_FILE_EOF'
// Offline fallback lexicon. Three lenses per symbol, each bilingual
// (id/en) so the reading follows the UI language toggle instead of
// being locked to one language per lens.
// Used when no ANTHROPIC_API_KEY is set or the API call fails.

export const LEXICON = {
  air: {
    match: ["air", "water", "sungai", "river", "laut", "sea", "ocean", "hujan", "rain", "banjir", "flood", "berenang", "swim"],
    theme: "emotion",
    jung: {
      en: "Water is the classic image of the unconscious itself. Clear water suggests you can currently see into your own depths; murky or flooding water suggests emotion rising faster than the ego can integrate it.",
      id: "Air adalah citra klasik dari alam bawah sadar itu sendiri. Air jernih artinya kamu lagi bisa ngeliat ke dalam diri sendiri dengan jelas; air keruh atau banjir artinya emosi lagi naik lebih cepat dari yang bisa dicerna egomu.",
    },
    primbon: {
      id: "Air jernih dalam primbon umumnya pertanda rezeki dan kejernihan pikiran akan datang. Air keruh atau banjir memperingatkan gosip atau urusan yang meluap — jaga ucapan beberapa hari ke depan.",
      en: "Clear water in primbon generally signals fortune and clarity of mind on the way. Murky water or floods warn of gossip or matters overflowing — watch your words for the next few days.",
    },
    islamic: {
      en: "Clear water in the Ibn Sirin tradition is often read as knowledge, purity of livelihood, or blessings. Turbid water can indicate trials or unclear matters — a prompt for patience and prayer for clarity.",
      id: "Air jernih dalam tradisi Ibn Sirin sering dibaca sebagai ilmu, rezeki yang bersih, atau berkah. Air keruh bisa jadi pertanda ujian atau urusan yang belum jelas — isyarat untuk sabar dan berdoa minta kejelasan.",
    },
  },
  ular: {
    match: ["ular", "snake", "serpent"],
    theme: "transformation",
    jung: {
      en: "The snake carries transformation and instinctual energy — the part of you that sheds skins. A calm snake that doesn't strike often marks a transition you are ready for, not a threat.",
      id: "Ular bawa energi transformasi dan naluri — bagian dari dirimu yang lagi ganti kulit. Ular tenang yang nggak nyerang biasanya nandain transisi yang kamu udah siap hadapin, bukan ancaman.",
    },
    primbon: {
      id: "Ular dalam primbon sering dibaca sebagai kedatangan jodoh, tamu penting, atau rezeki yang tidak terduga — terutama ular yang tidak menggigit. Ular putih khususnya dianggap pertanda baik.",
      en: "In primbon, a snake is often read as an incoming match, an important guest, or unexpected fortune — especially one that doesn't bite. A white snake is considered especially auspicious.",
    },
    islamic: {
      en: "Snakes are frequently interpreted as an enemy or a trial; however a snake that causes no harm may point to an adversary whose plans dissolve, or wealth with hidden responsibility attached.",
      id: "Ular sering ditafsirkan sebagai musuh atau ujian; tapi ular yang tidak menyakiti bisa menandakan lawan yang rencananya bubar, atau rezeki yang ada tanggung jawab tersembunyi di baliknya.",
    },
  },
  gigi: {
    match: ["gigi", "teeth", "tooth", "copot", "tanggal"],
    theme: "anxiety",
    jung: {
      en: "Losing teeth often accompanies anxiety about power, appearance, or a life stage ending — the bite you fear losing. Ask what in waking life feels like it is loosening.",
      id: "Gigi copot biasanya nemenin kecemasan soal kekuatan, penampilan, atau babak hidup yang berakhir — gigitan yang kamu takut hilang. Tanya diri sendiri, apa di kehidupan nyata yang kerasa mulai longgar.",
    },
    primbon: {
      id: "Gigi copot dalam primbon secara tradisional dikaitkan dengan kabar tentang keluarga — gigi atas untuk yang dituakan, gigi bawah untuk yang lebih muda. Dibaca sebagai isyarat untuk menghubungi rumah.",
      en: "In primbon, falling teeth traditionally connect to news about family — upper teeth for elders, lower teeth for younger relatives. Read as a nudge to reach out home.",
    },
    islamic: {
      en: "Teeth in the Ibn Sirin tradition map to household and kin. A falling tooth can signal news concerning relatives; without pain or blood the reading is considerably softened.",
      id: "Gigi dalam tradisi Ibn Sirin dikaitkan dengan keluarga dan sanak saudara. Gigi tanggal bisa jadi pertanda kabar soal kerabat; kalau nggak sakit atau berdarah, tafsirnya jauh lebih ringan.",
    },
  },
  terbang: {
    match: ["terbang", "fly", "flying", "melayang", "float"],
    theme: "ambition",
    jung: {
      en: "Flight is liberation from a constraint — or inflation, rising above a problem instead of through it. Note whether the flying felt free or fleeing.",
      id: "Terbang adalah pembebasan dari suatu batasan — atau bisa juga inflasi ego, naik di atas masalah bukannya nembus lewat masalahnya. Perhatiin, terbangnya kerasa bebas apa kabur.",
    },
    primbon: {
      id: "Terbang dalam mimpi sering dibaca sebagai naiknya derajat: kabar baik soal pekerjaan, status, atau cita-cita yang mulai terangkat.",
      en: "Flying in a dream is often read as a rise in standing: good news about work, status, or a goal starting to lift off.",
    },
    islamic: {
      en: "Flying can signify travel, elevation in rank, or ambition; flying too high without direction may caution against wishful plans not tied to effort.",
      id: "Terbang bisa menandakan perjalanan, kenaikan pangkat, atau ambisi; terbang terlalu tinggi tanpa arah bisa jadi peringatan soal rencana yang nggak dibarengi usaha nyata.",
    },
  },
  hamil: {
    match: ["hamil", "pregnant", "pregnancy", "bayi", "baby", "melahirkan", "birth"],
    theme: "transformation",
    jung: {
      en: "Pregnancy is the psyche gestating something new — a project, identity, or capacity not yet ready to be seen. Birth dreams mark the arrival of what was being prepared in the dark.",
      id: "Hamil adalah gambaran jiwa lagi mengandung sesuatu yang baru — proyek, identitas, atau kapasitas yang belum siap keliatan. Mimpi melahirkan nandain kedatangan hal yang selama ini disiapin diam-diam.",
    },
    primbon: {
      id: "Mimpi hamil atau bayi umumnya pertanda rezeki baru atau permulaan yang membawa tanggung jawab. Sering muncul menjelang usaha atau babak hidup baru.",
      en: "Dreaming of pregnancy or a baby generally signals new fortune or a beginning that carries responsibility — often arriving right before a new venture or life chapter.",
    },
    islamic: {
      en: "Pregnancy in dreams is often read as increase — of provision, of concerns, or of a matter growing in one's life. Context and the dreamer's state determine which.",
      id: "Hamil dalam mimpi sering dibaca sebagai pertambahan — bisa rezeki, bisa juga beban pikiran, atau urusan yang lagi berkembang dalam hidup. Konteks dan keadaan si pemimpi yang menentukan mana yang berlaku.",
    },
  },
  rumah: {
    match: ["rumah", "house", "home", "kamar", "room", "pintu", "door"],
    theme: "security",
    jung: {
      en: "The house is the self; its rooms are aspects of your psyche. Discovering new rooms means discovering unlived capacities. The condition of the house mirrors your inner state.",
      id: "Rumah adalah representasi diri; kamar-kamarnya adalah sisi-sisi dari jiwamu. Nemuin kamar baru artinya nemuin kapasitas yang belum pernah dijalanin. Kondisi rumah nyerminin keadaan batinmu.",
    },
    primbon: {
      id: "Rumah baru atau rumah bersih dibaca sebagai datangnya ketentraman dan rezeki; rumah rusak mengisyaratkan ada urusan keluarga yang perlu dibereskan.",
      en: "A new or clean house is read as incoming peace and fortune; a broken-down house signals family matters that need sorting out.",
    },
    islamic: {
      en: "A house often represents the dreamer's worldly state or spouse; entering a beautiful unknown house may signal blessings, while a crumbling one calls for attention to one's affairs.",
      id: "Rumah sering mewakili keadaan duniawi si pemimpi atau pasangannya; masuk ke rumah asing yang indah bisa jadi pertanda berkah, sedangkan rumah yang runtuh mengisyaratkan perlu perhatian pada urusan pribadi.",
    },
  },
  kejar: {
    match: ["kejar", "dikejar", "chase", "chased", "lari", "run", "running"],
    theme: "anxiety",
    jung: {
      en: "Being chased is the shadow demanding audience — a feeling or truth you keep outrunning. The pursuer usually weakens the moment you turn and look at it.",
      id: "Dikejar adalah bayangan (shadow) yang minta didengar — perasaan atau kebenaran yang terus kamu hindari. Si pengejar biasanya melemah begitu kamu balik badan dan ngeliatnya langsung.",
    },
    primbon: {
      id: "Dikejar dalam primbon sering dimaknai adanya persoalan yang belum selesai atau orang yang menaruh maksud — isyarat untuk waspada tapi tidak takut.",
      en: "Being chased in primbon often means an unresolved matter, or someone with an agenda toward you — a nudge to stay alert, not to be afraid.",
    },
    islamic: {
      en: "Being pursued may reflect an unresolved obligation or fear; escaping safely is generally read as relief from difficulty by God's leave.",
      id: "Dikejar bisa mencerminkan kewajiban yang belum tuntas atau rasa takut; berhasil lolos umumnya dibaca sebagai keringanan dari kesulitan, insyaallah.",
    },
  },
  mati: {
    match: ["mati", "meninggal", "death", "die", "dead", "jenazah", "funeral"],
    theme: "transformation",
    jung: {
      en: "Death in dreams is almost never literal — it is the end of a chapter, identity, or attachment, clearing ground for what follows. Grief in the dream honors what is completing.",
      id: "Kematian dalam mimpi hampir nggak pernah harfiah — itu adalah akhir dari satu babak, identitas, atau keterikatan, ngebersihin ruang buat yang berikutnya. Sedih dalam mimpi adalah bentuk penghormatan buat yang lagi selesai.",
    },
    primbon: {
      id: "Mimpi kematian justru sering dibaca terbalik: panjang umur bagi yang 'meninggal' dalam mimpi, atau akan datangnya perubahan besar yang membawa kebaikan.",
      en: "Death dreams are often read in reverse: long life for whoever 'died' in the dream, or a major change bringing good coming your way.",
    },
    islamic: {
      en: "Death of a living person in a dream is frequently interpreted as long life for them, or as repentance and a turning point in the dreamer's own path.",
      id: "Kematian orang yang masih hidup dalam mimpi sering ditafsirkan sebagai panjang umur buat orang itu, atau sebagai taubat dan titik balik dalam perjalanan si pemimpi sendiri.",
    },
  },
  jatuh: {
    match: ["jatuh", "falling", "fall", "terjatuh", "jatoh"],
    theme: "anxiety",
    jung: {
      en: "Falling is the ego losing its footing — a loss of control you haven't consciously admitted yet. It often shows up right when you're gripping too tightly somewhere in waking life.",
      id: "Jatuh adalah ego yang kehilangan pijakan — kehilangan kendali yang belum kamu akui secara sadar. Sering muncul justru pas kamu lagi genggam sesuatu terlalu erat di dunia nyata.",
    },
    primbon: {
      id: "Mimpi jatuh dalam primbon sering dikaitkan dengan kekhawatiran akan kehilangan posisi, jabatan, atau kepercayaan — isyarat untuk berhati-hati dalam mengambil keputusan.",
      en: "Falling in primbon is often tied to worry about losing a position, status, or someone's trust — a nudge to be careful with upcoming decisions.",
    },
    islamic: {
      en: "Falling can point to a decline in status or a warning against overreach; landing safely often softens the reading into a lesson rather than a loss.",
      id: "Jatuh bisa menandakan penurunan status atau peringatan agar tidak berlebihan; kalau mendarat dengan selamat, tafsirnya biasanya melunak jadi pelajaran, bukan kerugian.",
    },
  },
  telanjang: {
    match: ["telanjang", "naked", "nude", "bugil"],
    theme: "exposure",
    jung: {
      en: "Nakedness in dreams exposes the gap between how you present yourself and how you fear being seen. It surfaces when you feel judged, or when you're finally ready to stop hiding something.",
      id: "Telanjang dalam mimpi ngebuka jarak antara gimana kamu nampilin diri dan gimana kamu takut diliat. Muncul pas kamu ngerasa dihakimi, atau pas kamu akhirnya siap berhenti nyembunyiin sesuatu.",
    },
    primbon: {
      id: "Mimpi telanjang di depan umum dalam primbon sering dibaca sebagai rasa cemas akan aib atau rahasia yang mungkin terbongkar — bukan pertanda buruk, lebih ke pengingat untuk jujur lebih dulu.",
      en: "Being naked in public in primbon is often read as anxiety about a secret or shame that might come out — not a bad omen so much as a nudge to be honest first, before it's forced out of you.",
    },
    islamic: {
      en: "Exposure in a dream can point to a hidden matter close to becoming known; handled with humility, it's read as a prompt toward honesty rather than a threat.",
      id: "Ketelanjangan dalam mimpi bisa menandakan sesuatu yang tersembunyi hampir terungkap; kalau disikapi dengan rendah hati, ini dibaca sebagai dorongan untuk jujur, bukan ancaman.",
    },
  },
  ujian: {
    match: ["ujian", "exam", "test", "tes", "sekolah", "school", "kuliah"],
    theme: "anxiety",
    jung: {
      en: "Exam dreams are the psyche auditing itself — a fear of being measured and found lacking, often triggered by real evaluation happening in waking life, even informally.",
      id: "Mimpi ujian adalah jiwa lagi ngaudit diri sendiri — takut diukur dan dianggap kurang, sering dipicu penilaian nyata yang lagi terjadi di kehidupan sadar, bahkan yang informal sekalipun.",
    },
    primbon: {
      id: "Mimpi ujian atau sekolah dalam primbon sering muncul saat seseorang sedang diuji kesabarannya di dunia nyata — pertanda untuk tetap tenang menghadapi penilaian orang lain.",
      en: "Exam or school dreams in primbon often surface when someone's patience is being genuinely tested in real life — a sign to stay calm under others' judgment.",
    },
    islamic: {
      en: "Being tested in a dream often mirrors a real trial of patience or competence; performing calmly in the dream is read as reassurance about handling the real one.",
      id: "Diuji dalam mimpi sering mencerminkan ujian kesabaran atau kemampuan yang nyata; tampil tenang dalam mimpi dibaca sebagai jaminan bahwa ujian aslinya bisa dihadapi dengan baik.",
    },
  },
  uang: {
    match: ["uang", "money", "emas", "gold", "harta", "treasure", "kaya"],
    theme: "fortune",
    jung: {
      en: "Money in dreams rarely means money — it's a symbol of psychic value, self-worth, or exchanged energy. Finding it unexpectedly can mark a moment of recognizing your own worth.",
      id: "Uang dalam mimpi jarang beneran soal uang — itu simbol nilai batin, harga diri, atau energi yang dipertukarkan. Nemuin uang tak terduga bisa nandain momen kamu akhirnya sadar akan nilai dirimu sendiri.",
    },
    primbon: {
      id: "Mimpi menemukan uang atau emas dalam primbon umumnya pertanda rezeki, tapi juga peringatan untuk tidak sombong — rezeki dalam mimpi kadang datang dalam bentuk bukan uang di dunia nyata.",
      en: "Finding money or gold in a dream in primbon generally signals fortune, but also a warning against arrogance — the fortune promised sometimes arrives in a form other than money in waking life.",
    },
    islamic: {
      en: "Gold or money in a dream can represent provision or a burden depending on context; carrying it with ease is read more favorably than struggling under its weight.",
      id: "Emas atau uang dalam mimpi bisa mewakili rezeki atau justru beban, tergantung konteksnya; membawanya dengan ringan dibaca lebih baik daripada tertatih-tatih memikulnya.",
    },
  },
  api: {
    match: ["api", "fire", "kebakaran", "terbakar", "burning"],
    theme: "transformation",
    jung: {
      en: "Fire is raw transformative energy — passion, anger, or destruction that clears the way for renewal. Whether it feels purifying or threatening in the dream tells you which one it is.",
      id: "Api adalah energi transformatif mentah — gairah, amarah, atau kehancuran yang membuka jalan buat pembaruan. Kerasanya memurnikan atau mengancam di mimpi itu, itu yang nentuin mana yang berlaku.",
    },
    primbon: {
      id: "Api dalam primbon bisa bermakna ganda: rezeki yang berkobar kalau apinya terkendali, atau pertanda emosi yang perlu diredam kalau apinya mengamuk tak terkendali.",
      en: "Fire in primbon can go two ways: blazing fortune if the fire is contained, or a sign that emotions need cooling down if the fire rages out of control.",
    },
    islamic: {
      en: "Fire's reading swings on control — a contained flame can signal warmth, knowledge, or influence, while a raging fire warns against anger left unchecked.",
      id: "Tafsir api tergantung terkendali atau tidaknya — nyala yang terjaga bisa menandakan kehangatan, ilmu, atau pengaruh, sedangkan api yang mengamuk memperingatkan soal amarah yang dibiarkan tak terkendali.",
    },
  },
  mobil: {
    match: ["mobil", "car", "kecelakaan", "crash", "tabrakan", "motor", "kendaraan"],
    theme: "control",
    jung: {
      en: "Vehicles in dreams represent how much control you feel over the direction of your life. A crash or loss of brakes often mirrors a real decision that feels out of your hands.",
      id: "Kendaraan dalam mimpi ngewakilin seberapa besar kendali yang kamu rasa punya atas arah hidupmu. Kecelakaan atau rem blong biasanya nyerminin keputusan nyata yang kerasa di luar kendalimu.",
    },
    primbon: {
      id: "Mimpi kecelakaan kendaraan dalam primbon sering dibaca sebagai peringatan untuk lebih berhati-hati dalam mengambil langkah besar, bukan ramalan kecelakaan sungguhan.",
      en: "A vehicle-crash dream in primbon is often read as a warning to be more careful with a big upcoming step, not a literal prediction of an accident.",
    },
    islamic: {
      en: "A vehicle out of control in a dream can reflect anxiety about a path taken without full agreement from the heart — worth pausing to check the direction before continuing.",
      id: "Kendaraan yang lepas kendali dalam mimpi bisa mencerminkan kecemasan soal jalan yang diambil tanpa kesepakatan penuh dari hati — layak dijeda dulu buat ngecek arahnya sebelum lanjut.",
    },
  },
  cermin: {
    match: ["cermin", "mirror", "bayangan", "reflection"],
    theme: "reflection",
    jung: {
      en: "Mirrors in dreams are the self observing the self — what you see reflected, especially if it's distorted or unfamiliar, is the part of you seeking recognition.",
      id: "Cermin dalam mimpi adalah diri yang lagi ngamatin diri sendiri — apa yang keliatan di pantulannya, apalagi kalau terdistorsi atau asing, itu bagian dari dirimu yang lagi nyari pengakuan.",
    },
    primbon: {
      id: "Cermin dalam primbon sering dikaitkan dengan introspeksi diri — bayangan yang tidak sesuai kenyataan menandakan ada sisi diri yang belum sepenuhnya diterima.",
      en: "Mirrors in primbon are often tied to self-introspection — a reflection that doesn't match reality signals a part of yourself not yet fully accepted.",
    },
    islamic: {
      en: "A mirror often stands for self-knowledge or how one is perceived by others; a clear reflection is favorable, a cracked or unclear one calls for self-examination.",
      id: "Cermin sering mewakili pengenalan diri atau bagaimana seseorang dipandang orang lain; pantulan yang jernih itu baik, yang retak atau buram mengisyaratkan perlunya introspeksi diri.",
    },
  },
  gunung: {
    match: ["gunung", "mountain", "mendaki", "climbing", "puncak", "summit"],
    theme: "ambition",
    jung: {
      en: "Climbing represents the individuation journey — the slow ascent toward a fuller self. Struggle on the climb usually mirrors real effort you're putting toward a goal.",
      id: "Mendaki mewakili perjalanan individuasi — pendakian pelan menuju diri yang lebih utuh. Kesulitan di jalan biasanya nyerminin usaha nyata yang lagi kamu curahin buat satu tujuan.",
    },
    primbon: {
      id: "Mendaki gunung dalam primbon sering dibaca sebagai perjalanan menuju cita-cita yang tinggi — sampai di puncak pertanda keberhasilan, terhenti di tengah jalan pertanda perlu kesabaran lebih.",
      en: "Climbing a mountain in primbon is often read as the journey toward a lofty goal — reaching the summit signals success, getting stuck partway signals needing more patience.",
    },
    islamic: {
      en: "Ascending a mountain can represent striving toward a high goal or spiritual elevation; reaching the top is read as attainment, struggling partway as a call for patience.",
      id: "Mendaki gunung bisa mewakili perjuangan menuju tujuan tinggi atau kenaikan spiritual; sampai puncak dibaca sebagai pencapaian, tersendat di tengah jalan sebagai seruan untuk bersabar.",
    },
  },
  laut: {
    match: ["laut", "ombak", "tsunami", "gelombang", "wave", "storm", "badai", "petir", "lightning"],
    theme: "overwhelm",
    jung: {
      en: "Storms and great waves are overwhelming emotion breaking through the surface — feelings too large to have been consciously processed while awake.",
      id: "Badai dan gelombang besar adalah emosi yang membludak ke permukaan — perasaan yang terlalu besar buat udah bisa diolah secara sadar pas kamu bangun.",
    },
    primbon: {
      id: "Ombak besar atau badai dalam primbon sering menandakan gejolak emosi atau masalah besar yang sedang atau akan dihadapi — bukan untuk ditakuti, tapi untuk disiapkan.",
      en: "A great wave or storm in primbon often signals emotional turmoil or a big problem being faced or about to be — not something to fear, but something to prepare for.",
    },
    islamic: {
      en: "A great wave or storm can reflect an overwhelming trial approaching; surviving it in the dream is often read as reassurance that it will pass.",
      id: "Gelombang besar atau badai bisa mencerminkan ujian besar yang mendekat; berhasil selamat dalam mimpi umumnya dibaca sebagai jaminan bahwa ujian itu akan berlalu.",
    },
  },
  nikah: {
    match: ["nikah", "wedding", "menikah", "kawin", "married", "pengantin"],
    theme: "union",
    jung: {
      en: "Weddings in dreams often symbolize a union within the self — integrating two opposing parts of your personality — more often than a literal relationship.",
      id: "Pernikahan dalam mimpi sering melambangkan penyatuan di dalam diri sendiri — dua sisi kepribadian yang berlawanan lagi digabungin — lebih sering daripada soal hubungan beneran.",
    },
    primbon: {
      id: "Mimpi pernikahan dalam primbon justru kadang dibaca terbalik sebagai isyarat kesedihan atau perpisahan sesaat — bukan larangan menikah, tapi pengingat untuk lebih waspada terhadap perasaan.",
      en: "A wedding dream in primbon is sometimes read in reverse, as a sign of temporary sadness or separation — not a ban on marrying, more a nudge to stay attentive to your feelings.",
    },
    islamic: {
      en: "A wedding dream can be read either way depending on tradition — sometimes union and joy, sometimes a caution about separation; context and feeling in the dream matter most.",
      id: "Mimpi pernikahan bisa dibaca dua arah tergantung tradisinya — kadang penyatuan dan kebahagiaan, kadang peringatan soal perpisahan; konteks dan perasaan dalam mimpi itu yang paling menentukan.",
    },
  },
  mantan: {
    match: ["mantan", "ex", "pacar lama", "old flame"],
    theme: "unfinished",
    jung: {
      en: "An ex appearing in dreams is rarely about them — it's about an unresolved quality they represented: freedom, safety, recklessness. Ask what that person meant, not who they were.",
      id: "Mantan yang muncul di mimpi jarang beneran soal mereka — itu soal kualitas yang mereka wakilin dan belum selesai: kebebasan, rasa aman, atau kenekatan. Tanya, apa arti orang itu buatmu, bukan siapa mereka.",
    },
    primbon: {
      id: "Mimpi tentang mantan dalam primbon sering muncul saat ada urusan lama yang belum benar-benar selesai di hati — bukan tanda harus balik, tapi tanda untuk benar-benar melepaskan.",
      en: "Dreaming of an ex in primbon often surfaces when old business isn't truly settled in the heart — not a sign to get back together, but a sign to genuinely let go.",
    },
    islamic: {
      en: "Encountering a past partner in a dream often points to unfinished emotional business rather than a sign to reconnect — closure, not reunion, is usually the deeper message.",
      id: "Bertemu mantan pasangan dalam mimpi sering menandakan urusan emosional yang belum tuntas, bukan isyarat untuk balikan — penutupan, bukan penyatuan kembali, biasanya pesan yang lebih dalam.",
    },
  },
  kunci: {
    match: ["kunci", "keys", "hilang", "lost", "lose", "kehilangan"],
    theme: "loss",
    jung: {
      en: "Losing something valuable in a dream, especially keys, mirrors a real fear of losing access — to control, to a relationship, to a version of yourself you've relied on.",
      id: "Kehilangan sesuatu yang berharga dalam mimpi, apalagi kunci, nyerminin ketakutan nyata akan kehilangan akses — ke kendali, ke hubungan, atau ke versi dirimu yang selama ini kamu andelin.",
    },
    primbon: {
      id: "Kehilangan barang dalam mimpi menurut primbon sering dikaitkan dengan kekhawatiran akan sesuatu yang berharga dalam hidup nyata — bisa jadi peringatan untuk lebih menjaga apa yang dimiliki.",
      en: "Losing an object in a dream in primbon is often tied to worry over something precious in real life — a possible nudge to take better care of what you already have.",
    },
    islamic: {
      en: "Losing an object in a dream can reflect anxiety over losing something valued in waking life; finding it again, even in a later dream, is read as reassurance.",
      id: "Kehilangan barang dalam mimpi bisa mencerminkan kecemasan akan kehilangan sesuatu yang berharga di dunia nyata; menemukannya lagi, bahkan di mimpi berikutnya, dibaca sebagai jaminan ketenangan.",
    },
  },
  hewan: {
    match: ["kucing", "cat", "anjing", "dog", "burung", "bird", "ikan", "fish", "laba-laba", "spider"],
    theme: "instinct",
    jung: {
      en: "Animals in dreams carry instinctual material the conscious mind hasn't integrated — their behavior toward you usually mirrors how you're treating your own instincts lately.",
      id: "Hewan dalam mimpi bawa muatan naluriah yang belum diintegrasiin sama pikiran sadar — sikap mereka ke kamu biasanya nyerminin gimana kamu memperlakukan nalurimu sendiri belakangan ini.",
    },
    primbon: {
      id: "Hewan dalam mimpi menurut primbon punya makna berbeda-beda tergantung jenisnya, tapi secara umum hewan yang jinak pertanda pertemanan atau rezeki, sedangkan yang mengancam pertanda perlu waspada pada seseorang di sekitar.",
      en: "Animals in primbon carry different meanings depending on the species, but broadly a gentle animal signals friendship or fortune, while a threatening one signals caution around someone nearby.",
    },
    islamic: {
      en: "Animals in dreams often represent people or character traits in the dreamer's life; a gentle animal suggests a good companion, while an aggressive one may point to caution around someone nearby.",
      id: "Hewan dalam mimpi sering mewakili orang atau sifat tertentu dalam hidup si pemimpi; hewan yang jinak menandakan teman baik, sedangkan yang agresif bisa jadi isyarat waspada pada seseorang di sekitar.",
    },
  },
  makan: {
    match: ["makan", "eating", "food", "makanan", "lapar", "hungry"],
    theme: "nourishment",
    jung: {
      en: "Eating in dreams is about what you're taking in — literally or emotionally. Feeling satisfied versus still hungry in the dream often mirrors how nourished you feel in real life right now.",
      id: "Makan dalam mimpi soal apa yang lagi kamu serap — secara harfiah maupun emosional. Kerasa kenyang atau masih lapar di mimpi biasanya nyerminin seberapa terisi kamu ngerasa di dunia nyata sekarang.",
    },
    primbon: {
      id: "Mimpi makan dalam primbon umumnya pertanda kecukupan rezeki, tapi makan tanpa merasa kenyang bisa jadi isyarat ada kebutuhan batin yang belum terpenuhi.",
      en: "Eating in a dream in primbon generally signals sufficient fortune, but eating without ever feeling full can signal an inner need that hasn't been met.",
    },
    islamic: {
      en: "Eating in a dream is generally read as provision arriving; the type and quality of food often color whether it's read as pure blessing or something requiring caution.",
      id: "Makan dalam mimpi umumnya dibaca sebagai datangnya rezeki; jenis dan kualitas makanannya sering menentukan apakah ini berkah murni atau sesuatu yang perlu diwaspadai.",
    },
  },
  darah: {
    match: ["darah", "blood", "luka", "wound", "berdarah", "bleeding"],
    theme: "vitality",
    jung: {
      en: "Blood in dreams marks vital energy — where it's lost or shed often points to where you feel depleted, wounded, or forced to give more of yourself than feels sustainable.",
      id: "Darah dalam mimpi nandain energi vital — di mana darahnya hilang atau tertumpah biasanya nunjuk ke bagian dirimu yang kerasa terkuras, terluka, atau dipaksa ngasih lebih dari yang berkelanjutan.",
    },
    primbon: {
      id: "Mimpi berdarah dalam primbon sering dibaca sebagai pertanda rezeki yang datang lewat usaha keras, bukan selalu pertanda buruk — meski tetap perlu introspeksi soal kesehatan.",
      en: "Bleeding in a dream in primbon is often read as fortune arriving through hard effort, not always a bad omen — though it's still worth checking in on your health.",
    },
    islamic: {
      en: "Blood in a dream can be read as unlawful or hard-earned gain depending on context, and sometimes as a call to reflect on one's actions rather than a literal warning.",
      id: "Darah dalam mimpi bisa dibaca sebagai keuntungan yang tidak halal atau hasil kerja keras tergantung konteksnya, dan kadang sebagai ajakan merenungi perbuatan diri sendiri, bukan peringatan harfiah.",
    },
  },
};

// Generic, mood-aware fallback when no specific symbol matches —
// the reading is never a dead end, just less specific. Bilingual.
const GENERIC = {
  jung: {
    default: { en: "No single symbol dominates this dream, which is itself worth noting — it suggests the material is more atmospheric than symbolic, closer to processing a mood than solving a specific conflict. Pay attention to how you felt on waking rather than what happened in the dream.",
      id: "Nggak ada satu simbol pun yang dominan di mimpi ini, dan itu sendiri patut diperhatiin — artinya materinya lebih atmosferik daripada simbolik, lebih ke ngolah suasana hati daripada nyelesain konflik spesifik. Perhatiin gimana perasaanmu pas bangun, bukan apa yang kejadian di mimpinya." },
    tenang: { en: "The calm quality of this dream suggests your unconscious isn't currently in conflict with itself — a rare, worth-noticing state. Let it be a baseline you can return to.",
      id: "Ketenangan di mimpi ini nandain alam bawah sadarmu lagi nggak konflik sama dirinya sendiri — kondisi langka yang layak diperhatiin. Jadiin ini titik acuan buat kamu balik lagi ke sana." },
    aneh: { en: "Strangeness in a dream without clear symbols often means the material is still being processed into shape — not every dream arrives pre-digested. Give it a day or two before trying to interpret it further.",
      id: "Keanehan di mimpi tanpa simbol jelas biasanya artinya materinya masih lagi diolah jadi bentuk — nggak semua mimpi dateng dalam kondisi udah rapi. Kasih waktu sehari-dua sebelum coba ditafsir lebih jauh." },
    takut: { en: "Fear without a clear cause in the dream often points to something diffuse in waking life — a background anxiety not yet attached to a specific object. Ask what's been unnamed lately.",
      id: "Rasa takut tanpa sebab jelas di mimpi biasanya nunjuk ke sesuatu yang masih kabur di kehidupan nyata — kecemasan latar belakang yang belum nemplok ke objek spesifik. Tanya, apa yang belum dinamain belakangan ini." },
    senang: { en: "Unclouded happiness in a dream, without an obvious cause, sometimes marks a genuine release the conscious mind hasn't caught up to yet. Trust it more than you'd trust it while awake.",
      id: "Kebahagiaan tanpa awan di mimpi, tanpa sebab jelas, kadang nandain kelegaan asli yang pikiran sadar belum nyampe ke sana. Percaya itu lebih dari yang biasanya kamu percaya pas kamu bangun." },
    sedih: { en: "Sadness in a dream without a clear trigger is often the psyche processing a loss the conscious mind hasn't fully acknowledged yet — even a small one.",
      id: "Kesedihan di mimpi tanpa pemicu jelas biasanya jiwa lagi ngolah kehilangan yang pikiran sadar belum sepenuhnya akuin — meski itu kehilangan yang kecil." },
    vivid: { en: "Unusually vivid dreams tend to happen during periods of heightened processing — big transitions, decisions, or unresolved tension. The vividness itself is the signal, more than any single image in it.",
      id: "Mimpi yang terasa sangat nyata biasanya muncul pas lagi ada pemrosesan intens — transisi besar, keputusan, atau ketegangan yang belum selesai. Kenyataannya itu sendiri sinyalnya, lebih dari gambar spesifik apa pun di dalamnya." },
  },
  primbon: {
    default: { id: "Nggak ada simbol spesifik yang cocok di leksikon, tapi dalam primbon, mimpi yang samar-samar begini biasanya dibaca lewat perasaan yang tersisa pas bangun, bukan lewat detail kejadiannya. Kalau perasaannya tenang, itu pertanda baik; kalau gelisah, coba lebih hati-hati beberapa hari ke depan.",
      en: "No specific symbol matched in the lexicon, but in primbon, a hazy dream like this is usually read through the feeling left over on waking, not the plot details. If the feeling was calm, that's a good sign; if uneasy, be a bit more careful the next few days." },
    tenang: { id: "Mimpi yang tenang dalam primbon umumnya pertanda hari-hari ke depan akan berjalan lancar tanpa gejolak besar.",
      en: "A calm dream in primbon generally signals smooth days ahead without major upheaval." },
    aneh: { id: "Mimpi yang terasa aneh atau nggak jelas dalam primbon sering dianggap 'mimpi kosong' — bunga tidur biasa, bukan pertanda apa-apa. Nggak semua mimpi perlu ditafsir.",
      en: "A strange or unclear dream in primbon is often considered an 'empty dream' — ordinary sleep-noise, not a sign of anything. Not every dream needs interpreting." },
    takut: { id: "Rasa takut dalam mimpi menurut primbon sering jadi pertanda untuk lebih berhati-hati dalam waktu dekat — bukan soal mimpinya, tapi soal kewaspadaan yang perlu ditingkatkan.",
      en: "Fear in a dream, per primbon, often signals a need for more caution in the near future — not about the dream itself, but about raising your general alertness." },
    senang: { id: "Mimpi yang membawa rasa senang dalam primbon umumnya pertanda kabar baik akan datang, meski belum tentu bentuknya seperti di mimpi.",
      en: "A dream carrying happiness in primbon generally signals good news on the way, though it may not arrive in the same shape as it did in the dream." },
    sedih: { id: "Kesedihan dalam mimpi menurut primbon kadang dibaca terbalik — pertanda akan datangnya kelegaan setelah masa yang berat.",
      en: "Sadness in a dream, per primbon, is sometimes read in reverse — a sign that relief is coming after a hard stretch." },
    vivid: { id: "Mimpi yang terasa sangat nyata dalam primbon dianggap lebih layak diperhatikan daripada mimpi biasa — coba dicatat, siapa tahu maknanya baru jelas beberapa hari ke depan.",
      en: "A dream that feels unusually real, per primbon, is considered more worth noting than an ordinary one — write it down, its meaning may only become clear in the days ahead." },
  },
  islamic: {
    default: { en: "No specific symbol from the tradition matched this dream, but in the Ibn Sirin tradition, dreams without clear imagery are often classified as hadith an-nafs — the mind processing the day, not a message requiring interpretation. Not every dream carries meaning, and that's fine.",
      id: "Nggak ada simbol spesifik dari tradisi ini yang cocok, tapi dalam tradisi Ibn Sirin, mimpi tanpa gambaran jelas sering digolongkan sebagai hadith an-nafs — pikiran lagi ngolah harian, bukan pesan yang perlu ditafsir. Nggak semua mimpi punya makna, dan itu nggak masalah." },
    tenang: { en: "A calm dream without disturbance is generally read as a good sign, reflecting a settled state — a reassurance worth simply accepting.",
      id: "Mimpi tenang tanpa gangguan umumnya dibaca sebagai pertanda baik, nyerminin keadaan yang mapan — ketenangan yang bisa langsung diterima aja." },
    aneh: { en: "Dreams that feel confused or formless are often attributed to the mind's ordinary processing rather than to any deeper source — no interpretation needed.",
      id: "Mimpi yang kerasa bingung atau nggak berbentuk sering dianggap hasil dari pikiran yang lagi memproses hal biasa, bukan dari sumber yang lebih dalam — nggak perlu ditafsir." },
    takut: { en: "Fear in a dream without a clear cause is sometimes read as a prompt toward seeking protection and steadiness in waking life, more than a specific warning.",
      id: "Rasa takut di mimpi tanpa sebab jelas kadang dibaca sebagai dorongan buat nyari perlindungan dan ketenangan di kehidupan nyata, lebih dari sekadar peringatan spesifik." },
    senang: { en: "Unexplained joy in a dream is generally received as a good sign, though its form in waking life may look nothing like the dream itself.",
      id: "Kebahagiaan tanpa sebab jelas di mimpi umumnya diterima sebagai pertanda baik, meski bentuknya di kehidupan nyata bisa sama sekali beda dari yang di mimpi." },
    sedih: { en: "Sadness in a dream is sometimes read as preceding relief, following the pattern that hardship in a dream can foretell its opposite in waking life.",
      id: "Kesedihan di mimpi kadang dibaca sebagai pertanda kelegaan yang akan datang, mengikuti pola bahwa kesulitan di mimpi bisa jadi pertanda kebalikannya di dunia nyata." },
    vivid: { en: "A dream that feels unusually vivid is worth noting rather than dismissing, though the tradition still cautions against over-interpreting single dreams without a pattern.",
      id: "Mimpi yang terasa luar biasa nyata layak dicatat, bukan diabaikan, meski tradisi ini tetap mengingatkan untuk tidak berlebihan menafsirkan satu mimpi tanpa ada polanya." },
  },
};

export function genericReading(mood, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  const m = mood && GENERIC.jung[mood] ? mood : "default";
  return {
    jung: GENERIC.jung[m][l],
    primbon: GENERIC.primbon[m][l],
    islamic: GENERIC.islamic[m][l],
  };
}

// ---- Holistic synthesis for the offline path. Ties matched symbols
// into one connected reading instead of a list of separate lookups. ----

const THEME_LINE = {
  emotion: { id: "perasaan yang lagi naik ke permukaan, lebih cepat dari biasanya kamu olah", en: "feeling rising to the surface faster than you're used to processing it" },
  transformation: { id: "sesuatu di dalam dirimu lagi ganti bentuk, meski belum kelihatan dari luar", en: "something in you changing shape, even if it's not visible from outside yet" },
  anxiety: { id: "kekhawatiran yang belum sempat kamu ucapin ke diri sendiri secara sadar", en: "a worry you haven't consciously admitted to yourself yet" },
  ambition: { id: "dorongan buat naik level, entah itu status, posisi, atau pencapaian", en: "a pull toward rising — status, position, or achievement" },
  security: { id: "urusan soal rasa aman, entah itu rumah, keluarga, atau fondasi hidupmu", en: "something about safety — home, family, or the foundation of your life" },
  exposure: { id: "rasa takut ketahuan atau dinilai, dan diam-diam juga capek nyembunyiin sesuatu", en: "fear of being seen or judged, and quietly tired of hiding something" },
  fortune: { id: "pertanyaan soal cukup apa nggaknya kamu sekarang — secara materi maupun rasa dihargai", en: "a question about whether you have enough right now — materially or in feeling valued" },
  control: { id: "rasa nggak sepenuhnya pegang kendali atas arah hidupmu belakangan ini", en: "a sense of not fully holding the wheel of your own direction lately" },
  reflection: { id: "lagi ngaca ke diri sendiri, nyari bagian mana yang belum diakui sepenuhnya", en: "looking at yourself, searching for a part not yet fully acknowledged" },
  overwhelm: { id: "sesuatu yang lebih besar dari kapasitasmu buat nampung sekaligus", en: "something bigger than your current capacity to hold all at once" },
  union: { id: "penyatuan dua sisi yang tadinya kerasa terpisah dalam dirimu", en: "a merging of two sides of yourself that used to feel separate" },
  unfinished: { id: "urusan lama yang belum bener-bener selesai, meski udah lama nggak dibahas", en: "old business that isn't truly finished, even if it's been unspoken for a while" },
  loss: { id: "kekhawatiran kehilangan akses ke sesuatu yang kamu andalkan", en: "worry about losing access to something you rely on" },
  instinct: { id: "sisi naluriah yang belum sepenuhnya kamu percaya atau dengarkan", en: "an instinctual side you haven't fully trusted or listened to" },
  nourishment: { id: "pertanyaan soal apa kamu lagi cukup terisi, secara batin maupun fisik", en: "a question about whether you're being fed enough, emotionally or physically" },
  vitality: { id: "berapa banyak dari dirimu yang lagi terkuras buat orang atau hal lain", en: "how much of yourself is currently being spent on someone or something else" },
};

export function synthesizeOverall(hits, mood, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  if (!hits || hits.length === 0) {
    return l === "en"
      ? "No specific symbol anchored this dream, so read it by feeling rather than image — whatever mood you woke up with is probably the most honest summary of what it was processing."
      : "Nggak ada simbol spesifik yang jadi jangkar di mimpi ini, jadi bacanya lewat perasaan yang tersisa, bukan lewat gambar. Mood pas kamu bangun kemungkinan besar rangkuman paling jujur soal apa yang lagi diproses.";
  }

  const symbols = hits.map((h) => h.key);
  const themes = [...new Set(hits.map((h) => h.theme).filter(Boolean))];

  const sequence = l === "en"
    ? `This dream moves through ${symbols.join(", ")} in that order — worth noticing not just what showed up, but what came before what.`
    : `Mimpi ini bergerak lewat ${symbols.join(", ")} secara berurutan — yang penting bukan cuma apa yang muncul, tapi apa yang muncul duluan sebelum apa.`;

  const themeLines = themes.slice(0, 2).map((t) => (THEME_LINE[t] || {})[l]).filter(Boolean);
  const themeSentence = themeLines.length === 2
    ? (l === "en"
        ? `Underneath, it's holding two things at once: ${themeLines[0]}, and ${themeLines[1]}.`
        : `Di bawahnya, ada dua hal yang lagi dipegang bareng: ${themeLines[0]}, sama ${themeLines[1]}.`)
    : themeLines.length === 1
    ? (l === "en"
        ? `Underneath, the throughline is ${themeLines[0]}.`
        : `Di bawahnya, benang merahnya adalah ${themeLines[0]}.`)
    : "";

  const closing = l === "en"
    ? "Read the three lenses below as different angles on that same throughline, not three separate dreams."
    : "Baca tiga lensa di bawah sebagai sudut pandang beda dari benang merah yang sama, bukan tiga mimpi yang terpisah.";

  return [sequence, themeSentence, closing].filter(Boolean).join(" ");
}

// ---- Ties the dream's theme(s) to the dreamer's own known pattern
// (pancasuda from their weton) — only used when the dreamer is
// signed in and their profile is available. ----
const PANCASUDA_DREAM_NOTE = {
  Sri: { id: "watak dasarmu (Sri) biasanya bikin orang gampang percaya sama kamu — jadi kalau mimpi ini nyenggol soal dipercaya atau dikhianati, itu kemungkinan lebih berat buatmu daripada buat orang lain.",
    en: "your baseline temperament (Sri) usually makes people trust you easily — so if this dream touches on trust or betrayal, it likely lands heavier for you than it would for most people." },
  Lungguh: { id: "watak dasarmu (Lungguh) condong ke posisi dihormati — kalau mimpi ini ada unsur kehilangan kendali atau dipermalukan, itu kemungkinan nyentuh titik yang lebih sensitif dari biasanya.",
    en: "your baseline temperament (Lungguh) leans toward being respected — if this dream involves losing control or being embarrassed, it likely hits a more sensitive spot than usual." },
  Gedhong: { id: "watak dasarmu (Gedhong) condong nyimpen daripada nunjukin — kalau mimpi ini soal sesuatu yang kebongkar atau ketauan, itu kemungkinan mewakili ketakutan yang udah lama kamu pendam.",
    en: "your baseline temperament (Gedhong) leans toward holding things in rather than showing them — if this dream involves something being exposed or found out, it likely represents a fear you've been sitting on for a while." },
  Lara: { id: "watak dasarmu (Lara) emang lebih akrab sama gesekan dari biasanya orang — mimpi yang kerasa berat atau penuh konflik mungkin nggak seburuk yang kamu kira, itu emang pola normalmu buat ngolah sesuatu.",
    en: "your baseline temperament (Lara) is more used to friction than most — a dream that feels heavy or conflict-laden might not be as bad as it seems, it's genuinely just your normal way of processing things." },
  Pati: { id: "watak dasarmu (Pati) condong jadi yang nutup siklus — kalau mimpi ini ada unsur perpisahan atau akhir, itu kemungkinan bukan tanda buruk, tapi tandanya kamu emang lagi ngerjain peranmu.",
    en: "your baseline temperament (Pati) leans toward closing cycles — if this dream involves endings or separation, it's likely not a bad sign, just a sign you're doing the role you're built for." },
};

export function personalDreamNote(pancasudaKey, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  const note = PANCASUDA_DREAM_NOTE[pancasudaKey];
  if (!note) return "";
  return l === "en" ? `For you specifically: ${note[l]}` : `Khusus buat kamu: ${note[l]}`;
}

// ---- Recurring pattern across dream history. Real, computable
// personalization: counts how often each theme/symbol has shown up
// in the dreamer's past entries, not just this one dream. ----
export function findRecurringPattern(currentHits, pastDreamTexts, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  if (!currentHits || currentHits.length === 0 || !pastDreamTexts || pastDreamTexts.length === 0) return "";

  const currentKeys = new Set(currentHits.map((h) => h.key));
  const currentThemes = new Set(currentHits.map((h) => h.theme));

  const keyCounts = {};
  const themeCounts = {};
  for (const text of pastDreamTexts) {
    const hits = matchSymbols(text);
    const seenKeys = new Set(), seenThemes = new Set();
    for (const h of hits) {
      if (currentKeys.has(h.key) && !seenKeys.has(h.key)) { keyCounts[h.key] = (keyCounts[h.key] || 0) + 1; seenKeys.add(h.key); }
      if (currentThemes.has(h.theme) && !seenThemes.has(h.theme)) { themeCounts[h.theme] = (themeCounts[h.theme] || 0) + 1; seenThemes.add(h.theme); }
    }
  }

  const repeatedKey = Object.entries(keyCounts).sort((a, b) => b[1] - a[1])[0];
  const repeatedTheme = Object.entries(themeCounts).sort((a, b) => b[1] - a[1])[0];

  if (repeatedKey && repeatedKey[1] >= 2) {
    const [key, count] = repeatedKey;
    return l === "en"
      ? `This isn't the first time — "${key}" has shown up in ${count} of your recent dreams too. A symbol that keeps returning usually means the thing it represents hasn't been resolved yet, not that you're missing something by not "getting" it sooner.`
      : `Ini bukan yang pertama — "${key}" udah muncul di ${count} mimpimu yang lain belakangan ini. Simbol yang terus balik biasanya artinya hal yang diwakilinya emang belum selesai, bukan berarti kamu kurang peka buat "nangkep" maknanya.`;
  }
  if (repeatedTheme && repeatedTheme[1] >= 2) {
    const [theme, count] = repeatedTheme;
    const line = (THEME_LINE[theme] || {})[l];
    if (line) {
      return l === "en"
        ? `Zooming out across your recent dreams, this same underlying theme keeps surfacing in different disguises: ${line}. Seeing it ${count + 1} times now is worth taking seriously.`
        : `Kalau dilihat dari mimpi-mimpimu belakangan ini, tema dasarnya sama, cuma nyamar beda-beda: ${line}. Muncul ${count + 1} kali sekarang, ini worth diseriusin.`;
    }
  }
  return "";
}

export function matchSymbols(text) {
  const t = text.toLowerCase();
  const hits = [];
  for (const [key, entry] of Object.entries(LEXICON)) {
    const found = entry.match.some((w) => {
      const escaped = w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      return new RegExp(`\\b${escaped}\\b`, "i").test(t);
    });
    if (found) hits.push({ key, ...entry });
  }
  return hits;
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/moon.js" << 'NISKALA_FILE_EOF'
// Moon phase from synodic month approximation.
// Anchor new moon: 2000-01-06 18:14 UTC.

const SYNODIC = 29.53058867;
const ANCHOR = Date.UTC(2000, 0, 6, 18, 14) / 86400000; // days

const PHASES = [
  { max: 0.033, name: "New moon", icon: "new", note: "seed intentions, keep them private" },
  { max: 0.216, name: "Waxing crescent", icon: "waxing", note: "gather, tend, small consistent moves" },
  { max: 0.283, name: "First quarter", icon: "waxing", note: "friction is information — push through" },
  { max: 0.466, name: "Waxing gibbous", icon: "waxing", note: "refine and adjust before the reveal" },
  { max: 0.533, name: "Full moon", icon: "full", note: "peak charge — celebrate, release, don't decide" },
  { max: 0.716, name: "Waning gibbous", icon: "waning", note: "share, teach, distribute what ripened" },
  { max: 0.783, name: "Last quarter", icon: "waning", note: "cut what's done, forgive the rest" },
  { max: 0.966, name: "Waning crescent", icon: "waning", note: "rest, compost, dream deeply" },
  { max: 1.01, name: "New moon", icon: "new", note: "seed intentions, keep them private" },
];

export function getMoon(date = new Date()) {
  const now = date.getTime() / 86400000;
  const age = ((now - ANCHOR) % SYNODIC + SYNODIC) % SYNODIC;
  const frac = age / SYNODIC;
  const phase = PHASES.find((p) => frac <= p.max) || PHASES[0];
  const illumination = Math.round(
    ((1 - Math.cos(2 * Math.PI * frac)) / 2) * 100
  );
  return {
    ageDays: Math.round(age * 10) / 10,
    fraction: frac,
    illumination,
    name: phase.name,
    icon: phase.icon,
    note: phase.note,
    isWaning: frac > 0.533 && frac <= 0.966,
  };
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/planetary.js" << 'NISKALA_FILE_EOF'
// Planetary hours, Chaldean order.
// Uses fixed 06:00–18:00 day arc — near the equator (Indonesia)
// sunrise/sunset barely move, so this is honest, not lazy.

const CHALDEAN = ["Saturn", "Jupiter", "Mars", "Sun", "Venus", "Mercury", "Moon"];
// Day ruler by weekday, Sunday first:
const DAY_RULER = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"];

const FLAVOR = {
  Sun: "vitality, visibility, asking for what you want",
  Moon: "intuition, home matters, emotional honesty",
  Mars: "cutting, courage, workouts, hard conversations",
  Mercury: "messages, contracts, ideas, quick errands",
  Jupiter: "growth, generosity, big-picture planning",
  Venus: "beauty, connection, pleasure, making things lovely",
  Saturn: "boundaries, endings, slow patient work",
};

export function getPlanetaryHour(date = new Date()) {
  const ruler = DAY_RULER[date.getDay()];
  const startIdx = CHALDEAN.indexOf(ruler);
  const h = date.getHours() + date.getMinutes() / 60;
  // Hours 0..23 mapped from 06:00 start of the planetary day
  const sinceSix = (h - 6 + 24) % 24;
  const hourIndex = Math.floor(sinceSix); // each planetary hour ~= 1 clock hour here
  const planet = CHALDEAN[(startIdx + hourIndex) % 7];
  const nextPlanet = CHALDEAN[(startIdx + hourIndex + 1) % 7];
  return {
    dayRuler: ruler,
    current: planet,
    next: nextPlanet,
    flavor: FLAVOR[planet],
    nextFlavor: FLAVOR[nextPlanet],
  };
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/storage.js" << 'NISKALA_FILE_EOF'
// Thin storage layer. Swap these five functions for Postgres/Neon
// calls later without touching any component.

const DREAMS_KEY = "niskala.dreams.v1";
const PULLS_KEY = "niskala.pulls.v1";

function read(key) {
  if (typeof window === "undefined") return [];
  try {
    return JSON.parse(window.localStorage.getItem(key) || "[]");
  } catch {
    return [];
  }
}

function write(key, value) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(key, JSON.stringify(value));
}

export function listDreams() {
  return read(DREAMS_KEY).sort((a, b) => b.createdAt - a.createdAt);
}

export function getDream(id) {
  return read(DREAMS_KEY).find((d) => d.id === id) || null;
}

export function saveDream({ text, mood, symbols }) {
  const dreams = read(DREAMS_KEY);
  const dream = {
    id: `d${Date.now()}`,
    text,
    mood: mood || "",
    symbols: symbols || [],
    interpretations: null,
    createdAt: Date.now(),
  };
  dreams.push(dream);
  write(DREAMS_KEY, dreams);
  return dream;
}

export function updateDream(id, patch) {
  const dreams = read(DREAMS_KEY);
  const i = dreams.findIndex((d) => d.id === id);
  if (i === -1) return null;
  dreams[i] = { ...dreams[i], ...patch };
  write(DREAMS_KEY, dreams);
  return dreams[i];
}

export function listPulls() {
  return read(PULLS_KEY).sort((a, b) => b.createdAt - a.createdAt);
}

export function savePull(pull) {
  const pulls = read(PULLS_KEY);
  pulls.push({ ...pull, createdAt: Date.now() });
  write(PULLS_KEY, pulls);
}

export function todayPull() {
  const today = new Date().toDateString();
  return read(PULLS_KEY).find(
    (p) => new Date(p.createdAt).toDateString() === today
  );
}
NISKALA_FILE_EOF

mkdir -p "lib"
cat > "lib/synthesis.js" << 'NISKALA_FILE_EOF'
// Synthesis layer — turns computed signals (weton, bazi, moon,
// planetary hour) into readable text. Two entry points:
// 1. narrativeDailySynthesis — three short, jargon-free sections
//    for the home screen.
// 2. lifeAreaReading — a birth-chart-only read split into
//    love/career/health, deliberately blunt.
// Both take a `lang` param ("id" | "en").

import { ELEMENT_NAME, ELEMENT_TRAIT, elementRelation } from "./bazi";
import { DAY_MEANING } from "./astro";
import { getPlanetaryHour } from "./planetary";

function moonCategory(moon) {
  if (moon.fraction <= 0.05 || moon.fraction >= 0.97) return "new";
  if (moon.fraction < 0.48) return "waxing";
  if (moon.fraction <= 0.55) return "full";
  return "waning";
}

const MOON_TONE = {
  new: { id: "Bulan mati — apa pun yang kamu mulai sekarang, biarin diam-diam dulu.", en: "New moon — whatever you start now, let it stay quiet for a while." },
  waxing: { id: "Bulan lagi naik — ini fasenya bangun, bukan beresin.", en: "Waxing moon — this is a building phase, not a wrap-up phase." },
  full: { id: "Purnama — emosi dan hasil kerja sama-sama di puncak. Rayain atau lepasin, tapi jangan mutusin hal besar hari ini.", en: "Full moon — feelings and results both peak. Celebrate or release, but don't decide anything big today." },
  waning: { id: "Bulan lagi turun — waktunya ngelepas dan beresin, bukan mulai lagi.", en: "Waning moon — time to let go and tidy, not start over." },
};

// ---- Foundation: driven mainly by weton (gap between birth neptu and
// today's neptu, plus the actual pasaran meeting), moon as accent. ----
const FOUNDATION = {
  wetonDay: (ctx) => ({
    id: `Hari ini wetonmu muter balik — ${ctx.birthWeton} ketemu ${ctx.birthWeton} lagi, pas 35 hari sekali. Badan dan kepalamu udah tau duluan sebelum kamu sadar. Jangan isi hari ini sama hal baru, ini buat ngitung ulang, bukan mulai.`,
    en: `Your weton has looped back today — ${ctx.birthWeton} meeting ${ctx.birthWeton} again, once every 35 days. Your body knows before your head does. Don't fill today with new things. This one's for recalculating, not starting.`,
  }),
  same: (ctx) => ({
    id: `Neptu hari ini (${ctx.todayNeptu}) sama persis kayak neptu lahirmu — meski wetonnya beda (${ctx.birthWeton} ketemu ${ctx.todayWeton}), bobotnya kerasa akrab, kayak ketemu versi lain dirimu sendiri.`,
    en: `Today's neptu (${ctx.todayNeptu}) matches your birth neptu exactly — even though the weton itself differs (${ctx.birthWeton} meeting ${ctx.todayWeton}), the weight feels familiar, like running into another version of yourself.`,
  }),
  veryFar: (ctx) => ({
    id: `${ctx.todayWeton} (neptu ${ctx.todayNeptu}) ketemu weton lahirmu ${ctx.birthWeton} (neptu ${ctx.birthWeton_neptu}) — selisih ${ctx.gap} poin, salah satu jarak terjauh dari ritme normalmu bulan ini. Kalau hal kecil kerasa berat hari ini, itu bukan cuma perasaanmu.`,
    en: `${ctx.todayWeton} (neptu ${ctx.todayNeptu}) meets your birth weton ${ctx.birthWeton} (neptu ${ctx.birthWeton_neptu}) — a ${ctx.gap}-point gap, one of the widest from your normal rhythm this month. If small things feel heavy today, that's not just in your head.`,
  }),
  far: (ctx) => ({
    id: `${ctx.todayWeton} ketemu weton lahirmu ${ctx.birthWeton} — selisih neptu ${ctx.gap} poin bikin hari ini kerasa agak di luar jalur biasa. Nggak buruk, cuma nggak otomatis nyaman.`,
    en: `${ctx.todayWeton} meets your birth weton ${ctx.birthWeton} — a ${ctx.gap}-point neptu gap makes today feel a bit off your usual track. Not bad, just not automatically comfortable.`,
  }),
  near: (ctx) => ({
    id: `${ctx.todayWeton} ketemu weton lahirmu ${ctx.birthWeton} — selisih neptu cuma ${ctx.gap} poin, masih deket sama ritme normalmu, dengan gesekan kecil yang justru sehat.`,
    en: `${ctx.todayWeton} meets your birth weton ${ctx.birthWeton} — only a ${ctx.gap}-point neptu gap, still close to your normal rhythm, with a bit of healthy friction.`,
  }),
  veryNear: (ctx) => ({
    id: `${ctx.todayWeton} deket banget sama weton lahirmu ${ctx.birthWeton} — selisih neptu ${ctx.gap} poin doang. Hari ini kerasa hampir kayak default settingmu sendiri.`,
    en: `${ctx.todayWeton} sits very close to your birth weton ${ctx.birthWeton} — just a ${ctx.gap}-point neptu gap. Today feels almost like your default setting.`,
  }),
};

// ---- Growth: driven mainly by petung (weton-based daily fortune),
// with the bazi day-master relation woven in as a secondary accent. ----
const GROWTH_TEXT = {
  open: (ctx) => ({
    id: `Petung hari ini ${ctx.petungKey}: ${ctx.petungMeaning} Ini datangnya dari pertemuan wetonmu — ${ctx.birthWeton} ketemu ${ctx.todayWeton}.${ctx.baziClause}`,
    en: `Today's petung is ${ctx.petungKey}: ${ctx.petungMeaning} That comes from your weton meeting today's — ${ctx.birthWeton} meeting ${ctx.todayWeton}.${ctx.baziClauseEn}`,
  }),
  guard: (ctx) => ({
    id: `Petung hari ini ${ctx.petungKey}: ${ctx.petungMeaning} Godaan terbesarmu adalah maksain sesuatu yang harusnya ditunda — tahan, dan biarin ini lewat.${ctx.baziClause}`,
    en: `Today's petung is ${ctx.petungKey}: ${ctx.petungMeaning} Your biggest temptation is pushing something that should wait — resist, and let this one pass.${ctx.baziClauseEn}`,
  }),
  close: (ctx) => ({
    id: `Petung hari ini ${ctx.petungKey}: ${ctx.petungMeaning} Ada satu urusan yang udah kelamaan gantung — hari ini pas buat nutupnya, bukan buat nambah yang baru.${ctx.baziClause}`,
    en: `Today's petung is ${ctx.petungKey}: ${ctx.petungMeaning} Something's been hanging around too long — today's for closing it out, not adding anything new.${ctx.baziClauseEn}`,
  }),
};

// ---- Connection: driven mainly by the weton day's traditional
// meaning, with the planetary day-ruler woven in as a secondary accent. ----
const CONNECTION = {
  base: (ctx) => ({
    id: `${ctx.day} bawa watak ${ctx.dayMeaning}, dan itu warnain gimana kamu keliatan hari ini. ${ctx.planetClause} Ditambah watak dasarmu (${ctx.pancasudaKey}) — ${ctx.pancasudaFlavor}`,
    en: `${ctx.day} carries the character of ${ctx.dayMeaning}, and that colors how you come across today. ${ctx.planetClauseEn} On top of that, your baseline temperament (${ctx.pancasudaKey}) — ${ctx.pancasudaFlavorEn}`,
  }),
};

const PANCASUDA_FLAVOR = {
  Sri: { id: "orang gampang percaya sama kamu duluan hari ini, manfaatin buat nembus obrolan yang biasanya susah.", en: "people tend to trust you first today — use that to break into a conversation that's usually hard." },
  Lungguh: { id: "kata-katamu kedengeran lebih berbobot dari biasa hari ini, tapi jangan sampai kedengeran menggurui.", en: "your words carry more weight than usual today — just watch that it doesn't tip into lecturing." },
  Gedhong: { id: "kamu bakal lebih pengen nyimpen daripada berbagi hari ini — sah aja, nggak semua harus dibuka sekarang.", en: "you'll lean toward holding things back rather than sharing today — that's fine, not everything needs opening up right now." },
  Lara: { id: "kesabaranmu bakal diuji dikit lewat orang lain hari ini — pilih kapan worth-nya ngeladenin.", en: "your patience will get tested a bit through other people today — pick your battles on what's worth engaging." },
  Pati: { id: "kamu bakal ketemu momen buat nutup obrolan atau hubungan yang emang udah waktunya — nggak usah dipaksa lanjut.", en: "you'll run into a moment to close out a conversation or connection that's run its course — no need to force it further." },
};

const PLANET_ACTIVITY = {
  Sun: { id: "tampil dan minta apa yang kamu mau", en: "showing up and asking for what you want" },
  Moon: { id: "ngobrol jujur soal perasaan atau urusan rumah", en: "honest talk about feelings or home matters" },
  Mars: { id: "eksekusi hal yang butuh nyali atau olahraga berat", en: "executing something that takes nerve, or a hard workout" },
  Mercury: { id: "kirim pesan penting, tanda tangan, atau nego kecil", en: "sending an important message, signing something, or a small negotiation" },
  Jupiter: { id: "ngajuin hal besar atau mulai belajar sesuatu", en: "pitching something big or starting to learn something" },
  Venus: { id: "hal yang berhubungan sama koneksi, keindahan, kesepakatan", en: "anything about connection, beauty, or agreements" },
  Saturn: { id: "kerja fokus yang butuh disiplin, atau beresin utang lama", en: "focused disciplined work, or clearing an old debt" },
};

function findBestHour(now, targetPlanets) {
  // Prefer waking hours (06:00–22:00) first, only fall back to
  // overnight hours if nothing in that window matches.
  for (let h = 6; h <= 22; h++) {
    const d = new Date(now);
    d.setHours(h, 0, 0, 0);
    const p = getPlanetaryHour(d).current;
    if (targetPlanets.includes(p)) return { hour: h, planet: p };
  }
  for (let h = 0; h < 24; h++) {
    const d = new Date(now);
    d.setHours(h, 0, 0, 0);
    const p = getPlanetaryHour(d).current;
    if (targetPlanets.includes(p)) return { hour: h, planet: p };
  }
  return null;
}

// ---- Energy: moon illumination + neptu gap direction + bazi element,
// framed as embodied/physical guidance. ----
function energySection(ctx, moon, bazi, lang) {
  const l = lang === "en" ? "en" : "id";
  const risingMoon = moon.fraction <= 0.5;
  const moonLine = l === "en"
    ? `The moon is ${moon.illumination}% lit and ${risingMoon ? "still filling out" : "already past its peak"} — your physical energy today likely follows that same curve: ${risingMoon ? "building steadily rather than arriving all at once" : "better spent early than forced late"}.`
    : `Bulan lagi ${moon.illumination}% keliatan dan ${risingMoon ? "masih ngisi" : "udah lewat puncaknya"} — energi fisikmu hari ini kemungkinan ngikutin kurva yang sama: ${risingMoon ? "numpuk pelan-pelan, bukan langsung penuh" : "lebih baik dipakai di awal daripada dipaksa di akhir"}.`;

  const dmLine = bazi
    ? (l === "en"
        ? ` Your core wiring runs on ${ELEMENT_NAME.en[bazi.dayMaster.element]} (${ELEMENT_TRAIT.en[bazi.dayMaster.element]}), so when today feels off, that's usually the part of you asking for attention first.`
        : ` Wataknmu jalan di elemen ${ELEMENT_NAME.id[bazi.dayMaster.element]} (${ELEMENT_TRAIT.id[bazi.dayMaster.element]}), jadi kalau hari ini kerasa nggak pas, biasanya itu bagian dirimu yang minta diperhatiin duluan.`)
    : "";

  const gapLine = l === "en"
    ? ` With today sitting ${ctx.gap} points from your birth number, expect your usual stamina to run ${ctx.gap <= 2 ? "close to normal" : ctx.gap <= 5 ? "slightly off, nothing dramatic" : "noticeably different from a typical day"} — plan accordingly instead of assuming today is a baseline day.`
    : ` Karena hari ini berjarak ${ctx.gap} poin dari angka lahirmu, staminamu kemungkinan ${ctx.gap <= 2 ? "deket normal" : ctx.gap <= 5 ? "agak beda dikit, nggak drastis" : "kerasa beda banget dari hari biasa"} — rencanain sesuai itu, jangan anggap hari ini hari standar.`;

  return moonLine + dmLine + gapLine;
}

// ---- Decisions: petung tone + a real scan of today's planetary
// hours to recommend a specific window. ----
function decisionsSection(ctx, petung, hour, now, lang) {
  const l = lang === "en" ? "en" : "id";
  const activityMap = {
    open: ["Mercury", "Venus", "Jupiter", "Sun"],
    guard: ["Moon", "Saturn"],
    close: ["Saturn", "Moon"],
  };
  const targets = activityMap[petung.tone] || ["Mercury"];
  const best = findBestHour(now, targets);

  const baseLine = {
    open: { id: "Petung hari ini kebuka, jadi ini hari yang aman buat maju.", en: "Today's petung is open, so it's safe to move forward." },
    guard: { id: "Petung hari ini nge-rem, jadi hindari keputusan besar sampai keadaannya lebih jelas.", en: "Today's petung is holding back, so avoid big decisions until things are clearer." },
    close: { id: "Petung hari ini ke arah nutup, jadi fokus nyelesain, bukan mulai proyek baru.", en: "Today's petung leans toward closing, so focus on finishing, not starting anything new." },
  }[petung.tone][l];

  if (!best) return baseLine;

  const timeLabel = `${String(best.hour).padStart(2, "0")}:00`;
  const activity = (PLANET_ACTIVITY[best.planet] || {})[l] || "";
  const hourLine = l === "en"
    ? ` If you can time it, ${timeLabel} is ruled by ${best.planet} — a good window for ${activity}.`
    : ` Kalau bisa diatur, jam ${timeLabel} diampu ${best.planet} — jendela bagus buat ${activity}.`;

  return baseLine + hourLine;
}

// ---- Intuition: kliwon status + moon phase + shio + pancasuda tone,
// framed as a spiritual/gut-feeling note. ----
function intuitionSection(reading, moon, lang) {
  const l = lang === "en" ? "en" : "id";
  const parts = [];

  if (reading.today.isKliwon) {
    parts.push(l === "en"
      ? "Today is Kliwon — the day traditionally read as having the thinnest veil between the seen and unseen. Trust the first read on something, even if you can't yet explain why."
      : "Hari ini Kliwon — hari yang secara tradisi dianggap paling tipis batas antara yang kelihatan dan yang nggak. Percaya firasat pertama soal sesuatu, walau belum bisa dijelasin kenapa.");
  }

  const mc = moonCategory(moon);
  if (mc === "full") {
    parts.push(l === "en"
      ? "With the moon full, whatever's been building emotionally will want to surface today — let it, rather than talking yourself out of feeling it."
      : "Bulan lagi purnama, apa pun yang udah numpuk secara emosional bakal pengen naik ke permukaan hari ini — biarin aja, jangan malah dibujuk buat nggak ngerasain.");
  } else if (mc === "new") {
    parts.push(l === "en"
      ? "With the moon new, intuition works better inward than outward today — a private notebook entry will tell you more than a conversation would."
      : "Bulan lagi mati, intuisi lebih kerja ke dalam daripada keluar hari ini — nulis diary bakal ngasih tau lebih banyak daripada ngobrol sama orang.");
  }

  const pt = reading.pancasuda.tone;
  if (pt === "guard") {
    parts.push(l === "en"
      ? "Your baseline temperament runs on friction, which means your gut warnings tend to be real more often than you give them credit for — don't override a bad feeling just to be polite."
      : "Watak dasarmu jalan di gesekan, artinya firasat burukmu biasanya lebih sering bener dari yang kamu kira — jangan nimpa perasaan nggak enak cuma demi sopan.");
  }

  if (parts.length === 0) {
    parts.push(l === "en"
      ? "Nothing unusual in the spiritual weather today — a good day to simply notice what your gut says without needing it to mean something bigger."
      : "Nggak ada yang khusus dari sisi spiritual hari ini — hari yang bagus buat sekadar merhatiin kata hati tanpa harus dimaknai jadi sesuatu yang besar.");
  }

  return parts.join(" ");
}

const PLANET_ALIGNED = {
  id: (dayRuler, sign) => `Ditambah, hari ini diampu ${dayRuler} yang pas nyambung sama elemen ${sign}-mu — orang bakal lebih gampang baca niatmu, jujur kerasa ringan.`,
  en: (dayRuler, sign) => `On top of that, ${dayRuler} rules today and lines up right with your ${sign} element — people read your intentions more easily, honesty feels light.`,
};
const PLANET_MISALIGNED = {
  id: (dayRuler) => `Ditambah, hari ini diampu ${dayRuler} — bukan elemen alami zodiakmu, jadi mungkin kamu harus kerja dikit lebih keras buat dipahami.`,
  en: (dayRuler) => `On top of that, ${dayRuler} rules today — not your zodiac's natural planet, so you might have to work a bit harder to be understood.`,
};

export function narrativeDailySynthesis(reading, moon, hour, lang = "id", now = new Date()) {
  const l = lang === "en" ? "en" : "id";
  const { birthWeton, today, petung, isWetonDay, sign, dayMasterRelationToday, bazi, baziToday } = reading;

  const gap = Math.abs(birthWeton.neptu - today.neptu);
  let foundationKey;
  if (isWetonDay) foundationKey = "wetonDay";
  else if (gap === 0) foundationKey = "same";
  else if (gap <= 2) foundationKey = "veryNear";
  else if (gap <= 5) foundationKey = "near";
  else if (gap <= 7) foundationKey = "far";
  else foundationKey = "veryFar";

  // Bazi accent clause for growth (secondary, weton stays primary)
  let baziClause = "", baziClauseEn = "";
  if (dayMasterRelationToday && bazi && baziToday) {
    const dm = ELEMENT_NAME[l][bazi.dayMaster.element];
    const te = ELEMENT_NAME[l][baziToday.day.stemElement];
    const REL_ID = {
      produces: ` Ditambah lagi, elemen hari ini (${te}) nyalain elemen intimu (${dm}) — energi ngalir makin gampang.`,
      produced_by: ` Ditambah lagi, elemen intimu (${dm}) lagi diisi ulang sama elemen hari ini (${te}) — bagus buat nerima, bukan ngasih.`,
      controls: ` Ditambah lagi, elemen hari ini (${te}) nekan elemen intimu (${dm}) — jaga energi ekstra hati-hati.`,
      controlled_by: ` Ditambah lagi, elemen intimu (${dm}) lagi unggul atas elemen hari ini (${te}) — modal buat ambil inisiatif.`,
      same: ` Ditambah lagi, elemen hari ini sewarna sama elemen intimu (${dm}) — identitasmu kerasa jelas banget.`,
      neutral: "",
    };
    const REL_EN = {
      produces: ` On top of that, today's element (${te}) feeds your core element (${dm}) — energy flows more easily.`,
      produced_by: ` On top of that, your core element (${dm}) is being refilled by today's element (${te}) — good for receiving, not giving.`,
      controls: ` On top of that, today's element (${te}) presses on your core element (${dm}) — guard your energy extra carefully.`,
      controlled_by: ` On top of that, your core element (${dm}) has the upper hand over today's element (${te}) — good ground for taking initiative.`,
      same: ` On top of that, today's element matches your core element (${dm}) — your identity feels especially clear.`,
      neutral: "",
    };
    baziClause = REL_ID[dayMasterRelationToday] || "";
    baziClauseEn = REL_EN[dayMasterRelationToday] || "";
  }

  const ctx = {
    birthWeton: birthWeton.label,
    todayWeton: today.label,
    todayNeptu: today.neptu,
    birthWeton_neptu: birthWeton.neptu,
    gap,
    sign: sign.name,
    petungKey: petung.key,
    petungMeaning: petung.meaning[l],
    day: today.day,
    dayMeaning: DAY_MEANING[l][today.day],
    baziClause,
    baziClauseEn,
  };

  const foundation = FOUNDATION[foundationKey](ctx)[l] + " " + MOON_TONE[moonCategory(moon)][l];
  const growth = GROWTH_TEXT[petung.tone](ctx)[l];

  const alignedFire = ["Mars", "Sun"].includes(hour.dayRuler) && sign.element === "fire";
  const alignedWater = hour.dayRuler === "Moon" && sign.element === "water";
  const alignedEarth = hour.dayRuler === "Saturn" && sign.element === "earth";
  const alignedAir = hour.dayRuler === "Mercury" && sign.element === "air";
  const aligned = alignedFire || alignedWater || alignedEarth || alignedAir;

  ctx.planetClause = aligned ? PLANET_ALIGNED.id(hour.dayRuler, sign.name) : PLANET_MISALIGNED.id(hour.dayRuler);
  ctx.planetClauseEn = aligned ? PLANET_ALIGNED.en(hour.dayRuler, sign.name) : PLANET_MISALIGNED.en(hour.dayRuler);
  ctx.pancasudaKey = reading.pancasuda.key;
  ctx.pancasudaFlavor = (PANCASUDA_FLAVOR[reading.pancasuda.key] || {}).id || "";
  ctx.pancasudaFlavorEn = (PANCASUDA_FLAVOR[reading.pancasuda.key] || {}).en || "";
  const connection = CONNECTION.base(ctx)[l];

  const energy = energySection(ctx, moon, bazi, lang);
  const decisions = decisionsSection(ctx, petung, hour, now, lang);
  const intuition = intuitionSection(reading, moon, lang);

  return { foundation, growth, connection, energy, decisions, intuition };
}

// ---- Birth-chart-only life reading, split by area. Blunt on purpose. ----

const LOVE_BY_PANCASUDA = {
  Sri: { id: "Orang gampang tertarik ke kamu tanpa kamu usaha keras — tapi itu juga bikin kamu jarang bener-bener diuji soal siapa yang mau tinggal pas susah, bukan cuma pas gampang.",
    en: "People are drawn to you without much effort on your part — which also means you rarely get tested on who actually stays through the hard parts, not just the easy ones." },
  Lungguh: { id: "Kamu cenderung jadi pihak yang 'dihormati' dalam hubungan, bukan yang paling dimanja. Kalau diam-diam pengen lebih dimanja, itu nggak bakal dateng sendiri — harus diomongin.",
    en: "You tend to be the 'respected' one in relationships, not the pampered one. If part of you quietly wants more affection, it won't show up on its own — you have to ask for it." },
  Gedhong: { id: "Kamu nyimpen perasaan lebih lama daripada ngomongin. Pasangan yang cocok itu yang sabar nunggu, bukan yang nuntut jujur instan.",
    en: "You sit on feelings longer than you voice them. The partner who fits you is patient, not one who demands instant openness." },
  Lara: { id: "Pola hubunganmu historisnya penuh gesekan, dan itu bukan kebetulan. Bukan kutukan, tapi juga bukan alasan buat terus nolerin yang emang udah ngerusak.",
    en: "Your relationship history runs on friction, and that's not a coincidence. It's not a curse, but it's also not a reason to keep tolerating what's genuinely harmful." },
  Pati: { id: "Kamu sering jadi yang 'nutup' hubungan — ngakhirin, beresin, jarang yang mulai duluan dengan ringan. Kuat kalau memang perlu selesai, tapi bisa jadi pola ngindar kalau kepake terlalu cepat.",
    en: "You're often the one who closes relationships — ending, wrapping up, rarely the one who starts lightly. That's a strength when things genuinely need to end, but it can be an avoidance pattern if it fires too early." },
};

const CAREER_BY_DOMINANT = {
  wood: { id: "Kamu tumbuh lewat mulai dan meluas, bukan lewat ngerawat yang udah ada. Kerjaan rutin tanpa ruang berkembang bakal kerasa kayak sesak napas, bukan sekadar bosan.",
    en: "You grow by starting and expanding, not by maintaining what already exists. Routine work with no room to grow will feel like suffocation, not just boredom." },
  fire: { id: "Kamu butuh kelihatan buat ngerasa hidup di kerjaan. Kalau posisimu sekarang bikin kamu invisible, itu bukan soal mood — emang nggak cocok sama wataknmu.",
    en: "You need to be seen to feel alive at work. If your current role makes you invisible, that's not a mood problem — it genuinely doesn't fit your wiring." },
  earth: { id: "Kamu paling kuat di posisi yang nopang orang lain — koordinator, penghubung, yang bikin semua orang tetep jalan. Sering diremehin, tapi itu langka.",
    en: "You're strongest in roles that hold other people up — coordinator, connector, the one keeping everything moving. Underrated, but rare." },
  metal: { id: "Kamu unggul di presisi dan standar, bukan di ambiguitas. Lingkungan kerja yang serba longgar bakal ngikis energimu pelan-pelan.",
    en: "You excel at precision and standards, not ambiguity. A loose, 'good enough' work environment will grind your energy down slowly." },
  water: { id: "Kamu adaptasi lebih cepet dari kebanyakan orang, tapi itu juga berarti kamu jarang bener-bener berhenti cukup lama buat liat hasil jangka panjangnya.",
    en: "You adapt faster than most people, which also means you rarely stay still long enough to see the long-term payoff." },
};

const HEALTH_BY_LACKING = {
  wood: { id: "Elemen Kayu absen di chart-mu — tradisi ngaitin ini sama hati dan fleksibilitas tubuh. Kecenderungannya: kamu keras ke diri sendiri dan lambat pulih dari kekakuan, fisik maupun emosional. Ini bacaan energetik, bukan diagnosis — kalau ada gejala nyata, itu urusan dokter.",
    en: "The Wood element is absent from your chart — tradition ties this to the liver and physical flexibility. The tendency: you're hard on yourself and slow to recover from rigidity, physical or emotional. This is an energetic reading, not a diagnosis — if something's actually wrong, see a doctor." },
  fire: { id: "Elemen Api absen di chart-mu — tradisi ngaitin ini sama jantung dan semangat. Kecenderungannya: energimu gampang padam dan butuh usaha sadar buat 'nyala', nggak otomatis. Ini bacaan energetik, bukan diagnosis.",
    en: "The Fire element is absent from your chart — tradition ties this to the heart and drive. The tendency: your energy dims easily and needs deliberate effort to 'switch on', it's not automatic. This is an energetic reading, not a diagnosis." },
  earth: { id: "Elemen Tanah absen di chart-mu — tradisi ngaitin ini sama pencernaan dan rasa stabil. Kecenderungannya: kamu lebih rentan ke gangguan yang berhubungan sama stres dan pola makan nggak teratur. Ini bacaan energetik, bukan diagnosis.",
    en: "The Earth element is absent from your chart — tradition ties this to digestion and groundedness. The tendency: you're more prone to issues tied to stress and irregular eating. This is an energetic reading, not a diagnosis." },
  metal: { id: "Elemen Logam absen di chart-mu — tradisi ngaitin ini sama paru-paru dan batas diri. Kecenderungannya: kamu susah bilang cukup, ke kerjaan maupun orang, sampai tubuh yang maksa berhenti. Ini bacaan energetik, bukan diagnosis.",
    en: "The Metal element is absent from your chart — tradition ties this to the lungs and personal boundaries. The tendency: you struggle to say enough, to work or to people, until your body forces the stop. This is an energetic reading, not a diagnosis." },
  water: { id: "Elemen Air absen di chart-mu — tradisi ngaitin ini sama ginjal dan cadangan energi jangka panjang. Kecenderungannya: kamu jalan di atas cadangan yang lebih tipis dari kelihatannya, dan capeknya numpuk diam-diam. Ini bacaan energetik, bukan diagnosis.",
    en: "The Water element is absent from your chart — tradition ties this to the kidneys and long-term energy reserves. The tendency: you're running on thinner reserves than it looks, and fatigue builds up quietly. This is an energetic reading, not a diagnosis." },
};

const HEALTH_DEFAULT = {
  id: "Kelima elemen muncul di chart-mu tanpa ada yang bener-bener absen — tradisi baca ini sebagai keseimbangan dasar yang cukup baik. Bukan berarti bebas masalah, tapi nggak ada satu titik lemah struktural yang jelas. Ini bacaan energetik, bukan diagnosis.",
  en: "All five elements show up in your chart with none completely absent — tradition reads this as a fairly solid baseline balance. Not problem-free, but no single obvious structural weak point. This is an energetic reading, not a diagnosis.",
};

export function lifeAreaReading(reading, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  const { pancasuda, bazi } = reading;

  const love = (LOVE_BY_PANCASUDA[pancasuda.key] || {})[l] || "";

  let career = "";
  if (bazi) {
    career = (CAREER_BY_DOMINANT[bazi.dominant] || {})[l] || "";
    const dm = ELEMENT_NAME[l][bazi.dayMaster.element];
    const relToDominant = elementRelation(bazi.dominant, bazi.dayMaster.element);
    if (relToDominant === "controls") {
      career += l === "en"
        ? ` There's structural tension between your chart's dominant element and your day master (${dm}) — you likely feel like you're working hard without matching results, until you notice you're fighting your own pattern, not just circumstances.`
        : ` Ada tekanan struktural antara elemen dominan chart-mu sama day master-mu (${dm}) — kemungkinan kamu sering ngerasa kerja keras tapi hasilnya nggak sebanding, sampai sadar kamu lagi ngelawan pola diri sendiri, bukan cuma keadaan.`;
    }
  }

  let health = "";
  if (bazi && bazi.lacking.length > 0) {
    health = bazi.lacking.map((e) => (HEALTH_BY_LACKING[e] || {})[l] || "").join(" ");
  } else if (bazi) {
    health = HEALTH_DEFAULT[l];
  }

  return { love, career, health };
}
NISKALA_FILE_EOF

cat > "package.json" << 'NISKALA_FILE_EOF'
{
  "name": "niskala",
  "version": "0.2.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "@vercel/postgres": "^0.9.0",
    "bcryptjs": "^2.4.3",
    "jose": "^5.6.3",
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "resend": "^4.0.0"
  }
}
NISKALA_FILE_EOF

mkdir -p "public"
base64 -d > "public/logo.png" << 'NISKALA_B64_EOF'
iVBORw0KGgoAAAANSUhEUgAAA44AAAEKCAYAAABdSQtzAAC1AUlEQVR4nOzdd3hT1RsH8G+Spkmb7r33ZCMIRURARIYgiMpQkQ0t
e8h0AQ5A9p4ioP7AhVuWAyegIDK79957pGlyfn+UQkfGvWnGTXo+z8MDtDc3p2nGfc95z/vyXBwCQFEURVEURVEURVGq8I09AIqi
KIqiKIqiKIrbaOBIURRFURRFURRFqUUDR4qiKIqiKIqiKEotGjhSFEVRFEVRFEVRatHAkaIoiqIoiqIoilKLBo4URVEURVEURVGU
WjRwpCiKoiiKoiiKotSigSNFURRFURRFURSlFg0cKYqiKIqiKIqiKLVo4EhRFEVRFEVRFEWpRQNHiqIoiqIoiqIoSi0aOFIURVEU
RVEURVFq0cCRoiiKoiiKoiiKUosGjhRFURRFURRFUZRaNHCkKIqiKIqiKIqi1KKBI0VRFEVRFEVRFKUWDRwpiqIoiqIoiqIotWjg
SFEURVEURVEURalFA0eKoiiKoiiKoihKLRo4UhRFURRFURRFUWrRwJGiKIqiKIqiKIpSiwaOFEVRFEVRFEVRlFo0cKQoiqIoiqIo
iqLUooEjRVEURXGMvcRilY+LiIT7WpOHQm1J5wAJCfSwIq4OlmnWIkGEscdHUcbWr5M9WTcliBh7HBTVkVgYewAURVEUZe5srQUT
PRxFJ90dLeHhZAk3B0t4Oong5iCEncQCNmIBJFYCSMQCiIRq53T9AcQCQHWdvPFPrRxVdXKUVjYgs7AOOcVSZBVKkV1Uh8xCKU8q
UxjkZ6QoQwr0sMKYR1yx+8vMi0UVskHGHg9FdQQ8F4cAY4+BoiiKosyCSMhH10Ab0j3YBt2DbOHrJoKHowhWIuMl+BRXyJBVWIec
4nqkF9ThdmoVridV9quuk1822qAoiqIok0MDR4qiKIrSkquDZVrPEFv/7kE26BFsi3Bfa1gIeMYelkYKAiRl1+C/pEpcT6rE1cTK
9MKy+gBjj4uiKIriLho4UhRFURQLg7o7kiE9nfBwhB08HC2NPRydySutx/V7geSlu+XILKjjfgRMURRFGQwNHCmKoihKDYlYEPVY
V4dLj/d0Qv8u9rAWCYw9JINIyKrB+WslOPdPMTILaRBJ6V+kn4TEZlTT5xpFcRQNHCmKoiiqFSdb4alBPRwnDOnpiD7h9hBadOxr
WRpEUvriZCs8Nba/64ShvZyw+6tM/HWnnD6/KIqjaOBIURRFUQCEFjwM7uFExjzign6dHMCnl69K0SCS0gVvFxGZNswLo/u5AADm
7YrH1YQKrZ9PPUNsSWJ2zYiqWvlZnQ2SoqgWaOBIURRFdWiRfhIy5hFXjOjjDHsJ7VLFxpW4Chz+PrtdF/xUx+JsJzy7fLz/sOEP
O9//2tIDCfj5eimj59Bj3RxIZoEUqXm1948f84greeV5fwxYclXlOboF2ZDknFpaTZii2oF+QlIURVEdjr3EYtWoKJcNYx5xRZiP
tbGHY7L6Rtihb4QdriVWktc/SEZOsZQGkJRSFgIeZo30JnNGebf4+sc/5TEOGgGgoFSGj9d0RoOckJspVaislWPEw864lVql9Hgb
K8Hwj1Z3ORPgLkZeaf2l8etvxVTUNBxo309DUR0TXXGkKIqiOowAdzGZM8oHI/o4az6YYqW6To61J1Jw4VoJDR6pFiJ8JeTA4gg4
2LRcr7ibXo0X3r3N+vnSPdiWHFoSAZHwQX/Uby8V4fVjyW3O9WRvZ/LerJD7/3/tg2R8d7mIPkcpSgvG60hMURRFUQbi6yYm70wP
JqfXdqNBo55IxAJsnh2KacO8iLHHQnEDn8/D6kkB5NRrXdoEjVKZAssOJrb42uM9HUmYjzXxcRGRxeP8VD6PbiRX8lYeTmrxtb6R
dnB3tKxrfWxids39f9fVKxCbUa3dD0NRFE1VpSiKosyXt4uIRI/2wegoF2MPpcNYNM4XUpmC/O/nPLqq04E52Fhs/Hh1l5XeLiKl
3995OhO5rVKbK2vk+PT1rgCAb/4qVHv+grL6Fv93c7DEwSWRoskbb0+srJGfavp6am4tb/xbt8iArg747WYZknNq6fOSorREU1Up
iqIos+PhZEmiR/lgdD8XCGh5VIOTyhR4bv0tZBbQqqsdUa9QW/L+K51Ufv9OWjVe3KA8RXXZ835k8hOeKK6QYdrmu8hQ8RwaP8id
rJkUgGuJlfjwQi4ifK0R4SdBrVSBdR+mWNXVK9qsPlIU1T50xZGiKIoyG64OlmnRo7z9nx3gZuyhdGgiIR8LxvhgRat0Qsr8zRvj
Q2aN9FZ7zOvHklV+z9FGiF1fZiK3WIoIPwkyCpTHf90CbfD1X4V483gKDwAu3ihtx6gpimKCrjhSFEVRJk8iFkTNGOF1afpwL73e
T3GFDCm5tcgoqEN+aT3q6hWokylQV6+AtL7x79p6OYQCPqxEfFhZ8mElEsBKxIe1SAB3R0t4OYvg7dL4x9w9sfzfX4sqZIOMPQ7K
MHbPDycDujqoPebz3wrw9sepKleivV1EJLtIc3Xe/p0dyJ93yuiKNkUZEF1xpCiKokza5Cc8ycyRXjrvwfhfciX+TaxEam4t0vLr
kJRT41krVeTp8j48nCyJt4sYQR5iBHhYIcTbGsGeVnCxF+ryboymZ4jtwAv/lhh7GJQBHFgcQaIi7dUeU1evwN5vso6rO4ZJ0AgA
NGikKMOjgSNFURRlkob1diYLn/HVycpddZ0c15Mq8V9SJa4nVeJaYqVBLkrzSup5eSX1uJZQ0eLrErEgKsTb+lKPYBv0DLFFr1A7
2FoLDDEknQr2tgYNHM0fk6ARAE79ko/SStlUfYyhW5ANuZlSRYNJitIjGjhSFEVRJqV3mB15ZbwfInwl7TpPfmk9fvmvFBeuFRss
UGSquk5++UZyJe9GciWOn88FAIT5WJMewbboGWqL/p3tYWfN/Y9wiZh2/TJ3O+aGMQoaAeDULzpdsL8v1NuanFjZGa8eTSbfX6E9
GilKX7j/qUNRFGUAIiEfnQMkJMDDCv5uYvi7i+HmYAl7iQXsJRawsRIgp1iKzEIp/k2swM/XS5GYXUMvUAzI0VZ4bM2kgClDezlp
fY6sIil++rcEP/5bglupprU6kZBVw0vIqsGnv+YDAHqG2JLBPRwxuIcjfF3FRh6dcoR2dDRrc5/2IYO6OzI69ufrpcgrrdfLay6j
oI536pd8cpf2aKQovaLFcSiK6pAkYkFUv072l3qH2aFniC3Cfa1Zn+P3W2XYcDINOcXM9uRQ2hsV5UJWTgjQOl3z91tl+PDHXPwd
V2GWv6tgLysysJsjnnjICZ3827cSq0vvnkzDpxfzzfIx7+iG9nIim2eHMj4+ZmccLt0tp88FijJhNHCkKKrDkIgFUWP7u156vIcj
eoXZ6eSc5dUNiNkZh7vp1fSCSA/cHS3r3pwcJHqkM7NUuNa++L0AH17IRVp+x+knGORpRZ551BWj+rrA0da4RXZe3HAbd9Loa8Pc
hHpbk49Wd4ZIyCwVubJGjgFLrtLnAUWZOBo4UhRl9vzcxGTKk554qq8LxJa633OVWyzFc+tv9auuk1/W+ck7sPGD3Mnicb6wFrFb
ZayoacCnF/Nx8pf8c8UVsuF6Gp5JGNjNkTz9iAuG9NQ+vVdb2UVSPPXqfzRYMENfru1GAj2tGB9/+vcCrP9IdQsOiqJMA93jSFGU
2QrytCLRo7zxZG9nvd6Pp7MILw/1vLT/2yx6YaQDfm5isn5qEHoE27K6XVWtHMfP5+J/P+fRIP6eX2+W8n69WQp7icWqsf1dN7w4
xANuDpYGue/PfyswyP1QhjV/rC+roBEAfrpeqqfRUBRlSHTFkaIosxPkaUVinvbB0IcMt8pCV1d048UhHmT5eH9Wt6mskePEBRow
MvVkb2fy4uPu6M4yMGejrKoBI9f8F1kjlcfp7U4ogwvzsSafvt6V9e36zv+HJ5Up9DAiiqIMia44UhRlNgy1wqiMt4sIErEgigYu
2rGxEgxfPyX4zOM9mVVoBBp7L564kIuPfqQBIxvnrxbzzl8tRid/CZk81BMjHtb96+Wdj1NBg0bzs2FGCOvbxGfWgAaNFGUeaOBI
UZTJc3e0rFv2nJ/IGAFjczZWgovVdXJu9kXgsE7+ErJ5dii8XUSMb/P7rTK89VFqfkFZvYceh2bW7qZX81YfScK2zzPSpj7p6f/i
EN08lCcu5OLCvyV09d3MjI5yIcFe7FJUAeBGcqUeRkNRlDHQwJGiKJPF4wHjB7qThc/4QiLWrk2DLpVUymjQyNLEwe5k2XP+EFow
izOKK2TY9Ek6zl8tpoGJjhSW1Qds/jQdR87kHJv6pOeU8QPdYSXSrojUxRul2PFFBv3dmKH5Y321ul18Vo2OR0JRlLHQwJGiKJMU
4C4m66cGo1uQjbGHAgBIz6+DrIF2O2dKIhZErZsSdOkJFvtQv/yzEFs/Sx9RVSs/q8ehdVillbKp27/ImHr0bM6q6cO9NkwY5M6q
CvGer7Nw5IdsGjSaofGD3Im7ozZFlQgyC+t0Ph6KooyDFsehKMrkTBjkTlZPCjD2MFo48F02DtCqqoxE+ErItphQeDkzS03NL63H
mqPJuJZQQR9fA7K1Fkyc+qTXyecec4O9RPU88593yrDxZDoyCztOr8yO5sfNDxEXO7Y9QQl4PAWGr76J3OJ6+tygKDNAVxwpijIZ
znbCs+umBA17tIuDsYfSQkmlDCd/zltt7HGYgmf6u5I3Xw5ifPzl2HKsPJy0ury6YaMeh0UpUVkjP7X7q8xTu7/KRJ8IO9Inwh7e
ziLYSyyQVypFUnYtLseWIyW3lgYFZmxUlIvWQSN4hAaNFGVGaOBIUZRJiIq0J5tmhahd+TCWNe8ngwY2mq15IYCMH+jO+PiD32WD
9sbkhr/jKnh/x1UYexiUEUwYxPw126gpaFSgsqZBL2OiKMo4uHcFRlEU1crsp7zJ3Kd92nWOv+MqEJtRDVmDAmMfdQP7GXTlVh1J
wuXYchrcqOFkKzy1LSZ0Qg+GfQMrahqw+kgy/rxTRh9XijKiCF8J6RrIZh/5g6CRB4LqOpnexkZRlOHRwJGiKM6yl1is2jAjZMMj
ne21un1STi2On8/BT/+WtmhEfvxC7sQ988NPtqcB+r3qkUjLp/u61OkcICE7YsLg6sCssMbd9GosPZCAvBKa3kZRxjZxMJvVxgfp
qTwQgKdAjVSut7FRFGV4NHCkKIqTOgdIyNboMHhoUcnvbno19nydib/uKF8JrKyRnzp2Pvfk9hjmgWNGQR3S8+twLbECv/xXinQa
MGr09COuZP0U5vsZv71chNc/SKaPK0VxxOAejoyP5fHIvaDx3oojj0ChUOhxdBRFGRoNHCmK4pyJg93JqokBWt1206l0nPwlT23w
IRLysWicn9rz5BZL8fHPefgnvgLxmTU0mGFpzaQAMp7F3qgdpzNw7FwufZwpiiO6B9sSpnvKeTwFAMW9oPHeiiMUEGnTwYOiKM6i
gSNFUZwhtuSL108Jqn2ytzPr26bk1mLZwUSkMqjwuHy8PwlwFyv9XkVNAw5/n4MPf6RBjDbsrC2id84L298zhNlqbnWdHCsPJ+GP
23Q/I0VxycBuDgyPJGhMU2294qiAmAaOFGVWaOBIURQn2EssVu1fFLGhk7+E9W0v/FuCN44le9ZKFXmajh3Q1YE895ib0u/9cbsM
bx5POVdcIRvOehAUXOyFlw8vjewb6GHF6PicYinm7YpHah5t50BRXPNYN2Zpqk0BI9C0t/FeEAkCGyv60qYoc0IDR4qijM7LWUQO
LI6An5vyVUB1Nn+ajo9/Up+a2sTNwTLv3ekhSr+37kQKvvyzkF7laMnfXUwOLolkvCf1akIFlu5PjKmoaTig56FRFMWSSMhHiBeD
CaAWAeODaqpNK5C21jyILXmoqyf6HjJFUQZAA0eKoowq3NeaHFgUAUdbdu0xKmoasGR/Iq4lVDAK9ng8YMPMEHdba0GLrzfICRbv
S6Cpku0Q4SshB5dEMO6x+cftMizel8BrkNOLSYrios4BEkYvzvsBIx4EjI3B472v8RTwdxeS+ExaJZmizAENHCmKMpqoSHuyLSYU
1iKB5oObSciqwbIDicgsZF7ZdOqTXqRXaNt9d/N3x9M+jO3QJ8KO7Jgbxvh3eOFaCZYfSqSPN0VxWIQvky0DLdNTHxTFaZmu6uNq
gfjMev0OmKIog+AbewAURXVMo6JcyIHFEayDxm8vFWHyxjs8NkFjsJcVWTTOt83XZ2+PpUFjOwx9yIkcWhLJ+Hf47aUiGjRSlAmI
8LXWeMyDvY1QGjA2pauG+dIKORRlLuiKI0VRBjdrpDeZN8aH9e3Y7GdsbsOMtvsaF+1NwN9xzNJcqbaeHeBGXn8pkPHxn/9WgLc/
TqWPN0WZgGAvTYGjmtXGZhVWAYLuwTRwpChzQQNHiqIMavWkADKBRX+/JisPJ+Hc1WLWgce8MT4kzKflRdCao8n49WYpDWK0NHOk
N5nPIvD/6Mc8bPksnT7eFGUi3DUVueIBLYJHoG3weC+o7B1BA0eKMhc0cKQoymDWvhxExvZ3ZXWbunoFFu9L0CqltEuADZk10rvF
1977JB0/XCmiQYyW5o/xITNbPabqvH8mB7u/yqSPN0WZEBd79cXKGoNCAM0CxcZvtEpVvdeSI9DTgqTmNtD3AYoycXSPI0VReifg
87BjbhjroLG6Tq71PkSRkI8NM4NbfO3bS0X438/sU12pRqsmBrAKGj/+KY8GjRRlYtwdLes0H0UeBI8tVhrvfa9Vb8fHH2Lfaomi
KO6hgSNFUXq3a34YGdSdWTPpJhU1DZixJRY3U6q0CjwWPuNLfF0fXKzcTa/G68eSaRCjpVUTA8jEwcxTjI+fz8XmT2l6KkWZGhd7
oUj9EaTZ300rjWgVPN77/r3g8YleGk5JUZRJoIEjRVF6tXdhOOnf2YHVbcqqGjB9813EZVZrFXj0ibAjLw7xuP//onIZ5u2OP67N
uSjgzZeDWAWNH/6Yi+1fZNCgkaJMkIDP5KXbVE216d+Nq48t01TvfY9H0CtcCAcb/iq9DJiiKIOhgSNFUXqzZwH7oDGzoA6T3r2N
pJxarQIPiVgQ9fa0limqS/YnoLRSNlWb83V0b08LJs+wSDH+6Mc8bP2MBo0UZar4PPUvXx6v1api63+3KJzz4N/PDhRv0N0oKYoy
Bho4UhSlc0ILHvYuDCePdnFgdbvknFq8/N7d47nFUq0Dj7UvB11yc3hQxW/zp+m4lapdumtHxufzsHFmCBkV5cL4Nh//RKunUpSp
4zO5MrwfHDZfdWz6VlPhnJZfnzqC7nOkKFNHA0eKonRuy5xQ1iuNN1Oq8PKmO/3aszI4oo8zGdrL6f7/f7peolXfRwrYPDuEDH/Y
mfHxX/1ZSPc0UpQZ4GlYcXxwYNM/VKxA8loGlh5OfAzva9n8YIqiTAxtx0FRlM5YCHjYsyCcREXas7pdQlYN5u6KG1FdJ7+s7X17
OFqS11580JA+t1iK1z9IidT2fB0VnwdsjQ4jg3swL2b0d1wF1n+USoNGyuy5O1rWdQmwEbk5WMLexgJyOUFcZjV+v1VmNs//Wqmc
wVHK4j91aauNoseIcfZKvfaDoyjKqGjgSFGUTmgbNKbm1mLWttjVVbXys9reN48HvDc7FBKxAADQICdYtC8BNVJ5nLbn7KjWTw1m
FTQm5dRi0b54T4WCLiRQ5qtfJ3syabAHHuvmoPT7ReUy8uGPuTh+PtfkA8iSChnzgzX+tC3TVrsECjCir5CcuSIz+ceJ0o5ELIjq
GWJ7yc3REs62QggEPMSmV+PXm6X0OWECaOBIUZRO7JgbplXQOH1r7PHy6oaN7bnvl4d6km5BNvf/v/WzDCRk1dAPIZZeed6f1Z7G
3GIp5myPPVcrVeTpcVgUZTReziKy5oUAaNqv7WIvxJJn/TCkpxNZsCd+dXvf04wpr7SeB+VLim0RMAgeW1r5ohhnrrAITimz4Ggr
PPbiEI8pkwa735/kba64QkY+/60Apy7mH6fF7LiL5+IQYOwxUBRl4nbPDycDujqwuk1qbi1mbI39pKRSNrE99x3kaUVOr+12//8X
b5Ri8b4EGjSyNHOkN5k/xofx8VW1ckzedAepudpVv6Uornumvyt58+Ug1rdLzK7B8+tvmfTr4vftvYmtdduLewDg8RQATwEeTw4e
Gv++/3+e4t73m/7d+DfQ/PtyrD9Wi+Nn6apjR8DjARMHeZAFz/jAWqT8OdVcVa0c0zbfRWI2nfzlIloch6IorfF5wPaYMNZBY1p+
HaZtubupvUGjoLHy5/3/F5TV4/VjyZPac86OaNwAN1ZBo6yBIHpHHA0aKbO1fLy/VkEjAIR6W2PWSG+Tzt0uKGOwD7HNT6js7YCn
9LgVL4jg7coz6ceI0szLWUSOr+hMVk70ZxQ0AoCNlQCHlkTAw5EWUuIiGjhSFKW1N18OYrUfDmhsuTH1vTubyqoa2t0Mes4obxLm
Y33//68cTERljfxUe8/bkTzV14W88VKg5gObefWDZNxOoy1OKPO0eXYoeXGIR7vO8fJQTx2NxjgSsmvUH0CAB4Fi87eCVl9TcZxY
BOxYIGrnKE2fnbVF9ICuDmYZIDnYWGx8f1kkmm8jYcrRVohtMWHg008ZzqGBI0VRWlkxwZ+MeYR5Y3gAyCyow6xtsZ/oImjsEmBD
Zj/lff//O09n4mYKDWbYGNLTibwzPZjVbfZ8nYXzV4vp40yZpVdfDGzR0kdbttYC9AyxNdmAIDa9WuX3CGkZKDZvugEA5H7Q2LzD
I6/N8b0iBJgyQmCyj5EurJ8atL+wzPz2e4qEfOxfFLHS01n7yYFO/hIM6+3coZ8fXEQDR4qiWFsw1pe88Di7GfnsIimmbbl7pb3p
qUDjh9K7Mx4EPDdTqvDBuRwazLDQN9KebI0OZXWb768U4cgP2fRxpszSrJHe5PnH3HR2vkBPK52dy9DiMlUHjo00rDISDauRpDGF
de00Szwcwe+QwcGoKBcyqLsj4jKrze499b3ZISTST9Lu8zzFolgbZRg0cKQoipWZI73JjBFerG6TV1qPGVvuoqhcFqWLMSwa50v8
3MQAGvfbvfpBsi5O22EEeliRbSyDxpspVXjzeIrZXeBQFAA88ZATmcdiny8TVpame4kVl1ETo/q7rVcP732NNK1Gtl1dbPoaIbwW
QSUBDweXC+HpwqvT5fi5rpO/hLz+UiCSc2qNPRSdWzDWlwzsxm4Liyq9w+x0ch5Kd0z3XY2iKIN7cYgHqyIqAFBcIcOsbbFNJd7b
rVeYXYvVzgPfZSGzoI4GNAw52wnP7l8UobQcuirZRVIs2BO/ukHeIRcGKDPXOUDCOmWbiVqpQufnNJSKmoYD6lcdmwWF91YPCdQE
jUqDysZ/O9rycHSVhUhsqYcfhIM8HC3JrvnhEAn5uJ1WZezh6NTgHo6sJ5bVEVvy4WBjYbKtbcwRDRwpimJk3AA3sny8P6vbFFXI
MHXzXZ0FdiIhH29PfVDpMD6zBh+cM/2G24YiEvJxYHHEMA8n5ldo1XVyxOyMgyn3paMoVTwcLcm+hREQCXV/OZSUo6HADMf9ebtc
5fcIcC9gbNrHqCQoJA/+PPh+4x/S6nsR/nzsf8X89zvaWgsm7l4QDhc7IQDgj1tlxh2QDgV6WpHmVc51RcDn9dD5SSmt0cCRoiiN
RmpRebO4QoYZW3QXNALAsuf8SPPN9q99kAyFwuyvNXRm8+xQEuptrfnAZpbuT0AGXdGlzJCFgIfdC8JhL7HQ+blrpQrcTjPtvWt/
3SlT/c1mq4dtgkbCa1ZNtWXQSAiv2cojDwR8NK1aDuopwMdvCoi5rjw62QpPHV/R+WTz9+Dfb5eZ7kbYVt6bFaKXCZjiCtlwnZ+U
0hoNHCmKUuuRzvbkXZZpXEUVMkzbfBfp+boLOHqH2ZHxg9zv///wD9m0QTALqyYGkMe6ObC6zcZTabgSV0EfY8osrZkUwHoihanv
rxSZ/KTWtcRKnup021ZBYdPqIWm1sqj0e43B4oNVR/69AJKP/l0EOLlWQGys0MMAP6LBuDpYpn24qvOEoGYFk/6Oq0BdvcIs9nau
mOCvl9fSzRTzSuU1BzRwpChKpc4BErI9JozVbcqrGzBrW6xOV6msRHyPt5qlqOYUS3Hoe1rdk6kXh3iQiYPdNR/YzE/XS3Dql3z6
GFNmaXQ/FzJugO4qqLb20Y+5eju3IV28Uaryey3TVdWkoypddeTf/3pTcEnupa32DOPj5DrBdWc77ND3z2cI3YJsyMk1Xfy9XVq2
plD32JqSR7s4sK6yztRP10v0cl5KezRwpChKKX93MTmwKJJV6klVrRyztsUiNbdWpwHHknF+uc1TVF//IBmyBtOezTeUR7s4kGXP
s9ubmllYh1ePJptNChVFNRfqbU1eZ5l6z8YPV4qQpsNsC2P6/PcC1d8krVYWmweArb9H+G1WJAnh3/v6vRVHwge596drEB/ntgsW
9esCk36jnzTYg5xY2Rku9sI23/v+StFqIwxJp7xdRGTDDN3vawQAqUyBr/8q3KSXk1Nao4EjRVFtuDpYpr2/rBNsrZlX3qyRNhZR
ScjSbfpo6xTV078X4FpipVlclOlbpJ+EbI0OBZ/Fo1VXr8DCPQlmk0JFUc1ZiwQRO+aGwdJCP5c/dfUK7PoqUy/nNoZrCRW89HxV
bwVK0lHvryy2Ske9v59RWQDZdNuWwaOLnQAn11pgxYs8kwseHWwsNm6eE0pWTlQ+aXfuarHJFxwTCfnYNS+c1XUCG4e+z0ZZVcMq
vZyc0hoNHCmKasFKxPfYuyDcX9kMqTrzd8fjVmqVTgM6KxHfY32zFNXiChm2n86YpMv7MFeOtsJjO+aGsS5W8MbxFKTm6XbFmKK4
4t0ZwbGtUwZ1af1Hqcgr0U3rIa74Qs2qY9vAsPmqY2OgSJoHh+RBANkUIDb9u03weO/rc5+xwOl3BSTM1zRWH5/q60K+favHyqEP
Oak85vQfhQYckX6sfTmIBHvpJzHldloVjtGK6ZxEA0eKou7j83nYEROWG+bDfJO7QkEQszMO/+phFXDpc/65Xs1SVDd9ko7KGvkp
Xd+PubEQ8LBnfvgUd0d25Qk/uZiP81eL6Yc1ZZYmP+FJBnXXTWNyZbZ/kYEfrhSZ3evn678KV0tlDIrk3C9003o1sSmAbJaaSpgF
j01/9wwV4Px2Id6dwydOduDkSl0nfwk5siySvDM9WO0qXE6xFFdiy036eTJhkDsZ0cdZL+eukcqx/FAS5CZeXMpc0cCRoqj71r0c
RPpG2jM+nhDg1aPJuHRX9x+CfSLsyPOPPShecSWuggY1DK2bEkQ6B0hY3SY2oxqbP02njy9lljr5S8jiZ331dv7tX2Tg+HnzXCEp
r27YeOyc6mI/bYrg3A/4lKWjtiyG07TXsWXw2OxvCFp8bdITFvh9r3BlzDN8Yi2Cg0EeAA183URk48wQ8r81XdA7zE7j8Ye+zzbA
qPQnzMeadU9nNl77IBm5xVKzfC2ZAxo4UhQFAJg10puM7ufC6jabP03HmX90H8xJxIKot6a2bAHy7v9SdX03ZunFIR7kqb7sfo8V
NQ1YvC9B2iCnM7yU+bGXWKzaHhMGAZvNvizs+jLTbIPGJkfP5vDKqxtUfJfXMh31frGcViuKzVccoXzlsSlQvP834QNEcO//AoAI
YC0SYMULQvx9WFS6foYFCfIyzh5IV3vhf29M9iffvtUdwx9mtvqWXSTFV38WmuxzRWzJF++YGwYLgX5+hM2fpuPn66Um+/h0BLrv
ektRlMkZ29+VzBvjw+o2R37Ixv9+ztPLG/yy5/0uNU+zPH4+V6c9Ic1V3wg7rWaCXz2ajPzSerEehkRRRsXnAdtiwjawTdtmypxX
GpuTyhTY+nkG1k8JUn4A4TdubwTQGMYREPDA4z0IJnnggfD4AGlchyS8xmMJFODx+CCkMQQlaP03Ae6FowSk6UawFhO8NIyPl4YJ
ceWugnz+SwPOXJF71tQhT1+Pg7WIHzC0l33qk70d8WhXh8agljD/9e/80rQLJ73xUmBt8+0juvT2x6n4/LcCs38tmToaOFJUB/fE
Q07kjckqLgZUOP17AfZ8naWXN/g+EXZk3KMPUlTLqhqw/9ss2hpCA28XEdnGsucm0Liv8fdbZfTDmjJLc8f4kl6htno598ZTaR2q
1+k3fxXypgz1VFkQhZDG4BC8xn2K9+I7gHcvUCQADwoQXmM6a8vgsXGNkoCAxwMIIWj8hwK4Fzjifm2cpkDygb6RAvSNFGLzXOSe
/bsB3/3ZgJ+uNfCksvb9zE52gmNhPqIpvcIk6Bthg56hNs1SZ3mtRqFeQlaNSW+3GN3PhYxkmc3ChIIAKw8n4sK1EpN9bDoSGjhS
VAfWr5M92TQrhFW7hnNXi/HWx6l6eYOXiAVR70xrmaK65bN02hpCA2uRIGLfwghIxOzKoifn1GLLZ3RfI2We+kbak5kjvHR+XkKA
dR+mmHTKobaid8alX9jUU0VaQ1Nhm5YrisC9lUheU/AIEJ6iVfBIGrdJkgfBIa8pnOSRxu83CyB5aAoj22apDntYhGEPi0DAI3Hp
CqTkyJGQqUB8hhyFZQpU1wFVtQRVtYoRlTXkrLMd/5ijrWCKq4MAQZ6WCPa2RLCXCGE+YthZW7TZf3k/1fZeaxGm3vrIdLdbBHpa
kVdf0H3vU7mCYNmBRFy8QdNTTQUNHCmqg+oebEvY7vv58d8SrDycpLc3+BUT/C+5OjxIKbuZUoXvLptflUJd2zgzJNbfnX2m6SsH
EyFroPsaKfPj4WRJts4J1fl56xsUWHEoqcNe6BaW1QesO5FC3nxZVcrqvRVH0pSa2lgAh0f4SoLHZkuSaKza2hQs8qBom6J6LyJ9
EESq0/jrCfcVINzXEiP6olmfyfuFe848qOLavJrrg/2Z94v+tO5Teb+4DzOfXMzXebsqQxFb8sW75oZBbKnbsih19Qos2pdg8hVm
OxoaOFJUBxToaUX2Lghn9UHw550yvHIwUW9v8I92cSBjHnFt8bW3PzbdGVpDiR7lTR7r5sD6dm99lEr7NVJma8fcMNhY6bYxeV29
AvN2x+NaQkWHft18+Wchb3Q/V/KQihRgQviNASLQLF1VoSR4bLaPkQfwCO/eSiS5f1CLoLFFEHn/3pSMgNfi7+bVXe8Hfy2CwObB
Ysug8X5Bn3v9KJtXg31wP+oVV8iw83RmJKODOeitacG1vm663QJfXt2A2dtjEZ9Z06FfS6aIVlWlqA7Gztoieu+CcFYXVdcSK7F0
v/6CRolYELV+assZ7M9/K0BCFv1QUad3mB2ZM4pdUSMA+Pl6Kb74nRYhoMzTmkkBJMKXXTsaTSpr5Ji+5W6HDxqbzN8dH1kjlav8
PlFSPZXcD9LaVlS9fwwRNPt3yz+49/3GPw+Ob/uH3+L7rc/XZlzNx6Gsn2SzfpRNKapsVhvf+igVNVJ5XHsfc2N4doAbGfqQk07P
mVdaj5c23qFBo4migSNFdSAWAh72LAjfz6Yq2s2UKszbFWelugF0+62eFHDJyVZ4//+VNXLs/DJjkt7u0Aw42wnPbo0OBY/lR29+
aT1eP5bcTz+joijjGtTdkYwf5K7Tc5ZUyjDlvTu4m15NL3TvqZHK417ccEftMS2CrdaBIDQFhw8CvNY9HR8EhIL7ew5b/mkVQKJZ
8Ki0V2RT0MhTGjQ+2NfYesVRs2Pnck02rTnMx5q8/pJu9zWm5ddh8sY76ZkFtEq6qaKBI0V1IOumBJFuQTaMj4/NqEbMzrh++ixO
M6CrAxkV1bJS2+6vMlFZIz+lr/s0B5tnhw6zl7DfbbDycBKq6+SX9TAkijIqT2cReXdGsOYDWcgrqcfLG+8gJZemdbeWmlvLW/1+
kpojeEqDNOWrjgK06PvYbAWxZSDY/Gv3/o9Wf1oEkGpWHtusdj4ILpsHjU1B5YMVR2ZPhcux5dhxOsMknzdN/Rp1KSGrBlM23Vld
WFYfoNMTUwZFA0eK6iBmjvBi1Rg+MbsGs7bFjtBnkCERC6JaF1lIyKrBp792nBL32lg0zlfl/iJ1jvyQjf+SK+ljS5kdAZ+HLbND
YS3S3b7G5JxaTHr39vGsIil9zahw5u9i3icX89Ue0yZIw72gDm2Du+bHtg3qBK0CQoHKlcsHq5aCZiuNghYrjMru8/59Nw9w7wXA
TSuOTKTm1mLJ/gTPdj68RrNmUoBO+zX+l1yJaZvv9iuvbtios5NSRkGL41BUBzC0lxOZP9aX8fFZRVLM2R73SVWt/Kweh4VXXwi4
5GInbPG1dR+m6PMuTV6/TvZk2jD2LQYSs2uw/9tsegFMmaWFz/iSzgG629d4LaECC/cm9KOr85ptOJnG83UVk0c626s85n7BHPKg
X+O97wBAs6I3TY02FODxCBq7czQvjPPgNsoL4zT/luoiOUr/3aLCKq/lqiOL1hv5pfWI3hknrZUq8hjdgGOGP+xMnm5VqK49frvZ
WFivvkF/210ow6ErjhRl5h7pbE82z2Zelr60UoY522NRUimbqMdhYUBXhzbNhM/8XYw7aXQfkSoeTpZk06wQrW67/GAi5AraeoMy
P490tidTntTd4s5P10swY2ssjwaNzC3cG8/7O65C7THK00EfrD62LpLTfJ9iUzpr81XClmmpzXosttkPqSQVVtm/W4ypdVots4+l
0koZZm2LRX5pvW7LkBqIl7OIrFXVakUL314qwuJ98TRoNCM0cKQoMxbhKyFb5zDfp1BZI8fMbbHI1nNqlrVIELFuSssPpwY5wfYv
MtTnPHVgAj4P26LDYGfNPlHkvU/SkZZPixFQ5sfBxmLju9O1m0xR5ocrRViux7ZD5qpBTjB/t+bgseW+RyV7EJXsO2y7x7F12mrL
P7h/rrYVWFueV/2/W+xvZKCqVo7pW2ORYcKFXzbPDtVZv8bj53Px+rFkHp2vNC80cKQoM+XrJiYHFkfASsTsZV5Xr8DcXXFIztF/
EYjFz/rGNq+iCgAnf8lDQVm9h77v21Qtfc6PdPJnn4p3Ja4C//s5z2QvZChKFR4P2DQrdKWDjW523Xz1ZyFe/YBe6GqrvkGBBXvi
eVcYBo9tg7TWxXCaF8FpuW/xwQpk65XF1vshWwWorSqstvl3i72OzKunVtfJMWtbLFJNuIjS8vH+Okv3fvd/adj+hWkWBqLUo4Ej
RZkhBxuLjQcXR4DNBdWyA4m4lVql9zf6HsG2ZPzAluXyq+vkOPJDzmp937epGtDVgbw4hH1MXV0nx+sfJNNVXMosTX3Si/SNsNPJ
uT7+KQ9rT6TwCA0a20UqU2DhnnjepbvlDI7mtSlw07ptxoO001bFbpj2ckTrgjpNQaWg7X22/jfDoDGzoA6T3rmN2AzT3WYxsJuj
Vp8xrSkUBMsPJdICd2aMBo4UZWZEQj72L4pYyaYi2qtHk/HnnTK9v9ELLXh4a2rb/RMfnM0BrbamnJuDZZ62qXhrT6TQVVzKLHUJ
sCGLxjEv+KXOkR+ysfnTdHqhqyNSmQIxO+N4e7/OYnYDFRVSW/djbBs0ql9xbJ3e2rLCatPeymYrm017JhkGjABwJbYcE9+53c+U
01M9nUVkw8z2t7GRyhSI2RWPC9dKTPaxoDSjVVUpyozwecDW6FAS6cc83eTAd9n4/kqRQd7o5zzlTXzdWtYMKKmU4cMfaSqlMnwe
sD0mzN3Wmn2LgTP/FNMPcMosScSCqPdm62Zf4+ZP0/HxT/T9Rx8O/5DNu5ZYQTbNDIGrg6XmGxD+/aqpD6qsNlVUbVaJlUfuVU1t
qsiq5FT3/3Xvu/eL2/Du3VRZhVV2TlzIxbbPTT8dc+fcsHa3samukyNmZxxupug/a4kyLrriSFFm5NUXA8mjXRwYH//9lSIc+DbL
IG/0QZ5WZNrwtm0k9nyVBamMVlxTJuZpH632nBSVy/D2R6n99DAkijK6d6YHX2pvjzlCGlfkadCoX/8mVvKeXXcrhlnqahMelKeV
tl1BhIoVx6bvtS3C07KKK9sVRgDIKKjD9C132wSN66YEkR/fe8ikkp3fmBxIwnys23WOipoGTN9ylwaNHQRdcaQoM/HiEA/y7AA3
xsf/8l8pXj2abLA3+vVTgyDgt7y7lNxanP6jgH7YKNE7zI7MGumt1W3XHE0CbSVAmaPxg9zJoO6O7TqHXEGw6kgSXZE3kIqahgMx
O+MODOnpRBY+4wt/d6adKpr3XwQAAvCApo2oBExitAe/YtJs1VFbR87kYM9XmUpP8O2lIhSW1Wt9bkMb8bAzGfco82sGZcqrGzBz
aywSs2voa6mDoIEjRZmBIT2dyPLx/oyP//NOGZbsTzDYG/2kwR6kS4BNm6/v/irTUEMwKRKxIOrt6drtOTn5Sx7+jqugH+KU2Qnz
sSZrJgW0+zyL9yXg91v639NNtfTT9RLeT9dLMO5RNzJnlDfcHRmkr7bAA0hT4mprrYNI3f56byRX4s3jKWrbGl1NqOBdTdBUUZYb
PBwtyWsvBbbrHMUVMszYcpe2eupgaOBIUSauS4AN2TiT+X6fa4mVWLrfcH3K3Bws8xY/27aIRWxGNX75r5R+4CixYoL/JQ/WF1VA
VpEUO75QPhtOUaZMbMkXb50T2q5z1EoVmLc7Dv8mVtLXiBGd/qOA9/2VIkwc7E4mP+EJF3uh5htppJ9faXGFDHu+ysSXfxaa1XPm
vdmhkIi139dYWFaP6VtjkWnCRYEo7dDAkaJMmK+rmOxfFAGhBbP37rvp1Zi3K87KkHsK108NchcJ226n3ngq3WBjMCWPdLYnYx5x
ZX07uYJg+cFEul+UMktrXw6qbV1Yi43qOjnmbI/D7TS6D4sLpDIFjp/P5R0/n4unH3ElU4Z6ItjLytjDui85pxYf/piLr8wsYASA
OaO8SbegthlATOUWSzF9ayxyi6Vm99hQmtHAkaJMlIONxcb9iyPAtOJmfGYNZm+PHVFXr6jT89DuG/qQE4mKtG/z9T9ul+FGMp31
b83WWjBx/VTtUlQPfZ9t0n3EKEqVsf1dyfCHnbW+fXl1A2Zti0VCFt2HxUXf/FXI++avQjzWzYG8NMQTfXTUm1MbZ/8pxpd/FuJK
bLlZPlcifCVkzigfrW+fVSTF9M1382mbp46LBo4UZYJEQj72LYxY6ePCrLJgdpEU0TvjjlfVys/qeWj32VoLJq5SsR9p15d0b6My
a14IPOlixz5tKzajGge/yzbLCx2qYwvytCKr27GvsaCsHjNoSp1J+O1mGe+3m2WQiAVRj3ZxuNS/sz0GdneEvUR/l6p19QpciSvH
xf9Kce5qSWSNVB6nq3OLhHxOZYBYifgeW6NDwdfylZBVJMWUTXfOFVfIhut2ZJQpoYEjRZkYPp+HbTGhpJM/szYNJZWNG9hLK2VT
9TuylpaM8zvprCQIOvN3MZ35V2JoLycyQotVFbmCYM3RZD2MiKKMSyTkY+fcMChLdWciu0iKGVvvIq+knr7fmJDqOvnlc1eLeeeu
FgMAugbakC4BNgj3tUaEnzUifNm3KAIag8TMwjpkFNQhNa8O1xIqcOmuflYWXR0s09ZMCvA3ZBE6Td6cHJTrzXCyubXU3FrM3BZL
g0aKBo4UZWpeezGA9O/swOjYqtrGfT15pYa9cOoZYkvGqWgNsu/bLEMOxSS42Asvv/FSkFa3PfhdNlJzazlzcaKORCyI8ncXX7IW
CVDfoKB9vyi11rwQQLTd15hRUIep7939pKRSNlHHw6IM7FZqFe9WalWLr0X4SoiznRDWIj6sxAJYi/iwFglg2XySgRDkl9Yjo6AO
mYVSvaVXvvFSIBEIeLiZUoWbKVUQW/KxY24YYjOqVd5mxggv0ifCHqd+yTNIkbhxj7ppne6dll+HaVvubiqralil42FRJogGjhRl
QuaM8mbcd0kqU2De7niD91cS8Hl482XlQdC3l4poypgSm2aG9GW6V7W5hKwavH8mh7OPp4ONxcax/V1XPt7DCf7u4jYpZ+XVDeSn
f0vw+e8FuJtO92dSDzzZ21mrIlFA4+ti1rbY1eXVDRt1PCyKI+IyufN+seN0ZszHqzvvb/18Tc2rVXr8qCgXsmBsY6XxvhF2GLL8
37P6XMkL8rQiKycyb9fVXHJOLWZspUEj9YB2+R8URRncU31dSMxoZpva5QqCxfsSjFKAZtpwLxKgpMGzQkGw92u6t7G1SYM9SK8w
9sUg5AqClUeSIFcwaYJtWLbWgolLn/MjF7f2Wrl4nB+6Bdko3adkL7HAuAFu+N+aLpj7tA/3fhDKKDwcLck6FZNPmtxNr8a0zXf7
0aCR0jUvZ5HS96iKmoYDc3fHo7JG3uLrUpnyt7TWrZY8nUTDdDTENsSWfLG26d7JObWYtvluDA0aqeZo4EhRJuCRzvbkHRYN4V87
mqy3vRvqeLuIyPwxyoPbby4VGTxlluv83MRazwQf+p57KaoCPg8vPO5Bvnu7x8mXh3qyuu3sp7yxa144EVvyte+5QJmF92aHwkrE
/vLkv+RKzNh617O6Tn5ZD8OiOqCZI7zI+EHuZM4obzJxsLvK4zIL6njrP0ppfVv0DrNrEz1++mtBTF5pPYDG56w+W8Ssn6JdG5um
oLGipuGAHoZFmTAaOFIUx3UJsCHbY8IYH//Ox6k480+xUQKKdVOUrxIoFAQH6N7GFvg8YOPMEK1um5hdgyM/cCtF1c7aIvqD5Z3I
ign+WldBfKybA/YuCFee30V1CLNGatdj7lZqFebujI+slSry9DAsqoM6d7UEc0f7IGa0D+o1VEh1tG0sBieVKZBbLAUAbIsJhZ+b
uEXwWFHTcGD4quu8HnOu8Ka+d1dv7+NjHnElT/Zmv68xIasG07fcXU2DRkoZuseRojjM11VM9i+KYJxmsvfrLHz2W4FRAooRfZxJ
bxUpl3S1sa2pw7wYV8ZtTipTYPnBRE6lqHo6i8iRpZHQtmJfc73C7DBugBs5/btxnseU8UT6SUj0aG/Wt4vNqMac7XE6baVAUQCQ
WVjHu5pQQboE2GD8IHf8HV9B/o6rUPre1C3QBpU1cszdFYdbqVU8VwfLtF6htv6PdXPARz8adj7D101M1rwQwPp2qXm1dH8wpRYN
HCmKo5zthGcPLYkA06IpH/2Yh8M/GKeXn621YOIrz6tOuTz0fbYBR8N9QZ5WZOEzvlrddscXmUjL506BISdb4alDiyN0EjQ2WfSM
L07/XqCz81HcJxLysXlOKAQsm8wlZtdg1rbYETRopPSlpk6OcWtvRtZI5XGq9jkCgIeTJSZvvH3//bmwrD7g7D/FhhvoPdq2sUnN
q8X0LbHHadBIqUNTVSmKgyRiQdTBJZHDPJ2ZXYx/d7kIWz5LN1owsVhFz0YA+PqvQuQUSzkT6Bhbe1JUryVU4OQveZx6LPcuDJ+g
bcsEVewlFugT0XZvEGW+lj3nR3xYTj4kZtdg5tbY1VW18rN6GhZF4Y3jKbymiQl1n2Wr309O58Kk3ooJ/iTI04rVbZqCRkP3e6ZM
Dw0cKYqDds0LuxTixeyN//zVYrz2QbLRPqy6BNiQZ1X0bASAI2dyDDga7ps23IuE+Vizvl11nRyr30/O18OQtLZqYgCJ9NOuGbcm
A7s56uW8FPc83tORjB+kuvCIMim5tZi5labUUdxRWFYfYOwxDH3ISe3nsTIZBXWYuTX2HA0aKSZo4EhRHLNjbhjj9gx/3inDisNJ
Rp3hfGNyoMrvnfm7mPZtbMbbRXS/fxdbb3+UCn01sNZGv072aqsMthfTiRPKtHk5i8hbU5lXjAYaL3RnbKUpdRR32VlbREeP8iYS
sSDKUPfp5Swia1UUqFMlu0iK6VvuXtFnH0nKvNDAkaI4ZP2UIDKoO7OVlpspVVi6P9GoQdnEwe4qV88IAY6coXsbm1NVdVaTC9dK
jFYpVxlLCz5efVH1hIEuuDvpbs8kxU0CPg875oZBIma2jxsA8krrMX3L3St0dYTisl5htvujR/sgxNv6kiHuz0LA/rVUVC7DjC13
UVQuM1hwS5k+GjhSFEcsGOtLnn7EldGxSTm1iNkZ10+qoTy4PjnYWGxUt3r2y3+lSM7hVp9BYxr+sOqqs+oUlcuw9kRKPz0MSWvT
h3uy3o/GlqMNrd1m7pY868cqbZte6FKm4pf/SnkDl15bfSO50iCfga8878/qtVRaKcP0LXdptXOKNRo4UhQHPP+YG5kxwovRsXkl
9ZizPfacsZtcv/K8/0p1s5uHf6CrjU2sRYKI1ZMCtLrtyiNJMPbvujmxJV88dRiz52p71NYbb1KE0r/+nR3IS08wz7xuutDNLqKF
tijTYKhU6oHdHFltGyivbsD0rbHIoNtIKC3QwJGijGz4w86EadpfVa0cs7fHwtj7EXqG2JJRUS4qv//H7TLEZlTTD6V7Fj/rG2sv
Yb+CduqXfFxLUN4zzFhG9nGpFVvq/6OjorpB7/dBGYeLvfAym8rCVbVyzNpGL3QpqjVvFxF5dwbzPcJVtXLM2R6H1FyaDURphwaO
FGVEPUNsyTvTmb3pS2UKRO+IM/rFE5/Pw5svq9+rd/QsraTapGugDRk/kH0RmawiKbZ/kcG5D/dxA5ilU7dXSaXMIPdDGd6mWaF9
mfanratXYM6OWCTRtHeKasFCwMP2GOb7GmukjRMwcZl0UpfSHg0cKcpIAj2tyO754YwbXi87kIjbaVVGf8OfNNidBLir7tt3M6UK
/yYaZl+HKXh7GruKkU1WHU6CMfewKuNiJ7zYJcDGIPd1M6XKIPdDGdaLQzxIr1BbRsfKGgjm747HnTR6oUtRra0Yz3xfo1SmwNyd
8TQTiGo3GjhSlBE42wnPHlocARsrzTOFCgKsPJyEP26XGf0N387aInru0z5qjzl2nq42NokZ7UP81QTZqhw7l8uJSYLWeofbDTTU
ff2bWGmou6IMxN9dTBaP82N0rEJBsOxgAq5yLFWborhg6ENOjHufNmUr/WegQj2UeaNl60yQg43FRlsri5USsQASMR88Xsv3ArmC
oL5BgXoZgVSmQL1MAWkDOV4vUxzgUpGNjspaJIg4sDhimKuDJaPj13+YgnNXudGKIeZp7/3q0mLS8uvw8/VSTozV2ALcxWTOKG/W
t0vPr8OO09xLUQWAh0KYrRTpwo2USk+D3Rmld0ILHrZGh0FoofmpTQjw6tFk/HbT+JNlFMU1vm5i8hbDTBZZA8GCPfG4nkSDRko3
aODIEa4OlmmBHmJ/L2cRPBwt4e7U+Le9xAI2VgLYWAkgEQsgEmq9SDzl3h9IZQoUV8hQUFaPsqoGFJXLUFQhQ3F5PYorZcgrqcfd
dJrOoC875obFhnozSy/ZeCoNX/1ZyInfRaCHFZk0WH0VxBPncw00Gu7Ttmfjax8k63gkuhPoaWWQ+/n6r0LUShV5BrkzyiAWPuNL
QryYPX82nEzjVN9SiuIKkZCPHTFhYFqg7JWDifg7jq7aU7pDA0cDk4gFUeG+1pdCvKwR6ClGuI8EYT7WjFIWdUUk5MPLWQQvZ7V9
2Ehafh1+v1WK//2cj9xiWgJdF3bMDSN9Ipj18tt5OhOnfsnnzOO+5Fn1KWZFFTKc/qOAM+M1pnGPupHuwexX546fz8WtVO6lqDZx
MFBvxU9/zTfI/VCG0TfCjkx+gtkC8qHvs/Hpr9x536MoLlk1KYAEM5iAIQRYfigRv96kGUCUbtHAUY/CfKxJqLc1gr2sEO5rjRAv
a7g7MktP5IIAdzEC3D0x+QlPnL9aTDaeSv+kpFI20djjMlXvTg8mg7o7Mjr28A/Z+OBcDmfe8KMi7clj3RzUHvPxj3SBCACcbIWn
NAXZymQU1GHfN1mc+Z0r46BFSxG2bqVW0WIoZsTBxmLjplmhjI798s9Czr8GKMpYRvZ1Ic/0Z1bV+p3/peLHf0voa4nSORo46oi1
SBDxUKhtbI8QWzwUYouHGFaNMxVP9nZGv04OE948kTyB7mFj77UXA8nIvqr7Hjb38U952Ps1ty6elo/3V/t9qUyBz37LH2Gg4XDa
suf9JjBtNdDc6ve5V0W1NaLv8xNg3YkUPd8LZSg8HrBpVuhKJivVF2+U4q0PUzj1vkdRXOHrJiZvvMSs3/Per7Pw+W80+4fSDxo4
asnO2iL6oVDb/Q+H26FniC06+UuMPSS9s7UWYFt0GFYdSSJn6f4TxhaN8yXPPebG6NhPf83H5k/TOfXYPveYm8bUmC//KERVrfys
gYbEWQ+H25GnGE4QNHf4h2yTWGUrKpfBjWFRJ22c/CWP9uszI1Oe9CR9GaTmX0+qxPJDiTyFvmcmKMoEiYR87JzLbF/jxz/l4fAP
2fQ9lNIbGjiyEOhpRR7v4YhB3R3RJcAGvA760nxnejCyCqWEi+0CuGbmCC8ybZgXo2O/u1yEDSfTOPWYSsSCqEXPqE+7JAT46Eda
FMdCwMObL7MviJOYXYMD35rGB31BWb3eJslyi6XY81VWpF5OThlc5wAJWTDWV+NxSTm1mL87vp+sgUaNFKXM8vH+JIhBYbIz/xRz
buKZMj80cNTAw9GSjOnviqf6usDPjX0/NnMk4POwJToUw1ddN/ZQOG3iYHcyn8GFEwCcv1qM1z5I5twb/tynfS5pSrv87VYpsopo
8aQpT3oSHxe1BafakMoUWHEoCXITWWr5N7ESTPfpsiFXELxyKBE1Unmczk+uIx5OlsTFzhIyuQL5pfWbyqoaVhl7TFwlEQuitkaH
QcBX/7aQX1qP6O2xv9I2URSl3KDujowylv6Oq8CrR7l3DUGZHxo4qjDiYWcy9lE3MEmz6Yg8HC0xoo8zOfM3TVlVZmx/V7JqYgCj
Y/+8U4YVh5M49zgGeVqRF4eob78BAP/7iRbFcXe0rJv9FPuejbu+zERqnumkZl68UYqlz7Ev/KPJ68dSOJeqG+AuJsMedsajXRzQ
NdCm9bdXllc3rLyVWoV/4itw7mox8krqOTV+Y3pnevAlDw2F4Krr5IjeEYeiCtkgw4yKokyLp7OIvDtDc7/GuMxqLNoX76kwkQlI
yrTRwLGZIE8rMn6gO0ZFuRi0PYaperKXM878XWzsYXDO8IedyVqGKYu306qw7ECiYZrjsbR6UoDGY5JzanGF9ojCqokBIrY9Vv+J
r8DHP+WZ1GOXUVDHu55USXqG6K7415L9CfjlP+4U3JKIBVFzn/a5pGnSxF5igUe7OODRLg5Y8qwfriVWkuPnczp80/rxg9w1Vo9u
kBMs3BNvUpMmFGVIlhaN+xqtReqvRfNK6jFne9xq2veWMpQOHziKLfnikX1cap8d4IbOAeZf4EaXmDZz7kgGdXckG2eGMDo2OacW
c3fGx9TVK+r0PCzWBvdwJA+Ha15t/5DubcQjne3J4B7s0jer6+R49WiySTYrXHciBV+s7aYxDVGTipoGzNsVz6m+lY90tidvTQ2G
s52Q9W17hdqiV2g4/k2sJG+eSEFmQR1nfi5DCfS0ImsYTDi9cTwF1xIrO9zjQ1FMrZroT8J8rNUeU1kjx6xtsSivbthooGFRVMcN
HIM8rcjkoZ4Y3tsZViJ2KwVUI1+657OFXqG2ZMfcMEbH5pfWY86O2CsVNQ0H9DwsraycEKDxmKpaOWiqMrDmBWYl0pt7539pKCir
15wHzEFp+XW8DSfTyGsvsv+5m9xKrcKqI0nI5tDe2EXjfBkXslLnoVBbfPtWd2z+NJ2Y2opyewj4PGxiMGl24Nss/HClqMM8LhTF
1tCHnMi4Aer3NcoaCGJ2xiGzsONNUFHG1eECx0g/CZk50gtDejoZeygmr7pObuwhcEa4rzXZvSCc0bGllTLM3h6LonJZlJ6HpZWZ
I7yIh5Pmlgtf/1XI+b6D+jZjhBfrgjg/Xy81+Qvnz38r4CkUIG9MZhc81kjlOPJDDo6ezeHUz//6S4HkWQ0XamwtH++P/p0dyIrD
iSM6Qqua6NHeGldIzl0txoHvTKOCMEUZQ6CHFXlrmuZ9jauOJIFWtqeMocMEjt2CbMjsp7zxaBcHYw/FbJRXNxh7CJzg6yYmBxZF
aNyLADSm583aFov0fG7OEjraCo9NH8Fs1eWzX00y01Jn3Bws89gWxCmqkGHtiZQYPQ3JoE7/UcC7k15Fljzrh6hIe7XH3kmrxp93
yvDxT3mruZZWNSrKRedBY5NHOtvj0JLIM7O3x5p18NglwIbMGqn+tXAlrgIrOVgEjKK4QmzJF2+LDtXYr3Hb5xn46XoJfS1RRmH2
gWO3IBsSM9oH/Tqpv7Ch2LuRXGXsIRidk63w1OGlkXC01bwnqqpWjhlbYjnd4HzWSK8pTALgawkVSONo8Gsorzzv5862IM7rHySD
q+nJ2ojPrOFF74iDm4NlXq9QW3dfNzH4zfY+JmbV4O/48kmVNfJTRhymSi72wstMikC1Ryd/CfYuCD8z5b27Zvl6EQn50FT5MatI
iuUHE81iwoSi9OWtacG1gRr6NX7xewFOXMg1y/cSyjSYbeDo6yomr4z3w8Buuu85RjU6f61jV1S1s7aIPrgkYoKmsvNAY1rv7O2x
SMyu4ewbvqeziLzwOLNtd5/8WqDn0XBb7zA78mRvZ1a3+eL3Aly6W87Z3397FJTVe5z5x/TeD9a+HNRXItZ/Be3uwbZ4a1oweZ2D
vVrba/5YH6Kux7FUpsD8XXFmNWFCUbo27lE3MvQh9Vuo/rhdhnc+TjW79xDKtJhdVRixJV88f4wP+fbt7jRo1KOCsnpOldA3NDtr
i+j3X4ncH+qtfk8PANRKFYjeEYe76dzqU9fa/DE+jI4rq2rA+asduyjOay+x29uXXSTF5k/TaRliDnlxiAcx5NaF0VEuCPOxNqtG
a50DJOSlIZ5qj1l1JKnDZydQlDqh3tZk1SR/tcckZtdg2YFEHm3VSBmbWa04Pt7TkaycEAB3BitAulZQVo/SygaUVzdAKlOgrr7x
T229vPFvqQIWAh5EQj4sLXiwvPe3UMiHyIIPSyEPYks+3B0s4enMrtiGMWz+JN3YQzAae4nFqkNLIjcwCRqlMgXm7Y7jVMsBZcJ8
rMlTfV0YHfvF7x17tXHGCC8S4M6uovDq95PAxbYrHVWIlxVZPM7P4Pc7c4QXVhxOMvj96oNIyMfGGSHgqXlnO/R9tsEnGB1thcec
bS2m2FpboKy6ASUVMs7tq6WoJjZWguG754fD0kL1Ok5BWT2id8Sd6+jF6ChuMIvA0d3Rsm71pACRpqbD2qiVKpBTLEV2kbTF342B
ogylVQ39quvkl3V9vy52wotujpYDPZws4e4ggquDEJ5OIrg7WiLI0woONsb71f34bwku/NsxN2bbSyxWHV4auUFT9UCgMWhcsCce
/5pAv7KFz/gyPvbLPzpu4OjhZEnYFsR5/0wObqZwe+KgIxEJ+dg8OxRCC/W/koSsGvwTX4Gn+7nC1lo36az9Ojno5DxcsHpSAFHX
kun3W2XY902WXp/37o6WdU885CTq7C9BsJc1wn2Vvi9vqK6Tb/j2UhG+v1LE+Uk8UycS8hHmY028nBuvV9wdLeHmYAkbKwGKKmQo
KK1HQVk9coqluJlS1eGD+q1zQs+oq2JeI5Ujekcciitkww04rA6nk7+EeLs0Pmdd7S3h6WQJO4kFiitkyC+tR2GZDHmlUtxMqTrX
0X8XJh84vjjEgyx8xhdsi1SokpBVg5spVbiRUombKVVGq35ZVCEbVFQhw930aqXft7O2iA7ytNof5GWFIA8rBHiIEexppffVyn8T
K/HqUfPbp8OEvcRi1fuvdNoQ4sUs43DZgUT8HVfB+ceqV6gt45S9qwkVyOJQ7z1De/WFQFbvNck5tdj9VaZJPF4iIR+DujuSbkE2
8HCyhIPEArX1CtxOrcKVuApcT+L+BAgTy573I5oKUNxMqULMzrh+1XXyy99eKiJHl0cyqpqsia21ACIh3+Tb2Azr7UzG9ndV+f3U
vFqsPJwUqY/7drCx2DjmEdeVT/ZyRucACaPbSMQCTBzsjomD3XE5tpys+zAVucUd931Ml7oH25KugRJE+EoQ7msNJpk4zWw4f7V4
w47Tmchh8fvwcLQkI/q44NGuDvB2EaGpzkBSTi0uXCvG+aslSM3jbhG6JnNGeZO+aipSEwK8cjARKbnc/1lMSZcAG9ItyAYRvtYI
v/e8ZWHYz9dLya4vM1il4LvYCy+PeNil72PdHODjIrp/rZ6aW4uf/ivFmb+LkMzhwonN8VwcAow9Bq34uYnJW1OD0D3Ytl3nScuv
w5+3y/D7rTLcTKmKrJHK43Q0RKMQCfkI8rQiXQIk6BZsix7BNvB1ZZdWp8pnvxVgy6fpPFO/6NGGg43FxkNLIlcyWWkEgMX7EnDx
hmnsAT2xsjPpFmTD6NhXjybjexPvQaitgd0cyc55Yaxu8+y6m5z/MJCIBVELxvpeGtvfVW0Z+NtpVdj8aQZuJJtuADmouyPZMVf9
7/B6UiXm7orzrJUq8pq+ps3vXpUnVvx7has9XJnwdhGRz97oqjKQlsoUmPTObZ1f7PbrZE/GPeqGob3a34NZKlNg48k0fPlnock+
l40p0NOKjI5ywcg+LmDS81eTqlo51hxNwm83y9T+PiRiQdT8sT6XJg3WXMTtj9tlWHk4SS8ZYbowuIcj2R6j/j1l15eZnOt5a6p8
3cRkVF8XjOzrrJNr4lqpAmtPpOAcg3oPC5/xJdOHa25zdi2hAksPJHJ+Fd4kA8eJg93JqokBWt/+j9tl+ON2GX67WcZqlstUOdoK
jz0UYjulR4gNHgqxYzxL2yQxuwZ7vsrCrzdNIxDStXstNyYEM1xpXH4w0WRSeQd0dSC754czOraqVo4hy//tkBMHIiEfX63rRtis
6G//IgPHz3O7bHrPEFuyZU4onO00t5NpsupIEs7+Y3rFkdwcLPNOr+3mbmOlfuXw6ddvIKOg7UwymwkWVerqFYha8I/JPXZNBHwe
Tr7ahaibQHvro1R88XuBTn5GoQUPT/V1IS8P9USQhlVibWw8lYZTv+Sb7O/DkJzthGdHRbkMG9HHGRG+7K4hmHrjeAq++Ut5MO/r
JiaHl0aCSRXzJim5tZi9PZZzEzUB7mLyv1e7qM1iuHCtBMsPJdLnZjvYSyxWjYpy2TCijzO6BLTvvVuV9z5Jx/9+zlP6e3J3tKw7
tCRS5M+iJkJOsRSzt8VyOrPLpFJVRUI+1k0JIsMfZlcGHwBuJFfi28tFOH+1JKajlQUvrZRN/el6ydSfrpcAaHwcuwXZkB7BtugW
ZIOugTZt9kxW18nx478lOH+1BH/eUT8LaM48nUXk0OIIqNvL09zbH6eaTNAIAItYFAj54e8ik0+x09b04V6sgsZ/EytNImjcvyhC
Y7Pp1jbODEFOsZSY2r7Nd6YHu9tYCZBdJIVMTqCswNHp3wuUBo0AsPfrTBxc0r7sy7hM5VsPTMWicb5qg8afrpfoLGh8eagneflJ
T7iwmNRga9XEAMjlhHz2m27GbI56BNuSCYPdMYLFdVd6fh0Ss2uQXdRYDyKjoA61UgVEQj4GdnfAyD4uUDaBs35KEIrK68lfd1q2
LfJyFpEjSyNZFz4M8rTCwcWRfZ9dd5PV7fTJXmKxaveCcLVB4930arxmhq17DCXST0ImDXbH04+oTqdvLatIivjMauSV1CO3RIrc
4nqUVzdAaMFD/84OGNnXGU5K+nWvmOCPogoZaV1p3sVOePHw0kiRulZFyng5i3BoaSTGrb0p5mpBPZNZcfRwtCR7F0aA6aoPABRX
yPDpr/n45lIR3c9AsRbhKyEHFkcwLkR04NssHPgu22SeZ8MfdiYbZ4YwPv6Fd29zvqWIPvi4iMh37/RgfHxdvQLj1t7kdDaDr5uY
fPKa+hlvdW6mVOHlTXc4+/O1NnOEF5k/trEA1JT37mJbtPJV1mGrrkvzS+tVftLvXRhO+nd20Hocppzq/XC4HTm8VHXgXFQhw7g3
b7ZrYtZCwMMz/V3JrKe84eZgmOrodfUKjHrtP86tShmTSMjHU1EuZMJAd8b7v4rKZfji9wKcv1bMKD1//EB3svQ5vzYTV9lFUjz1
6n/3by8S8nHy1S6kPSvOWz5Lx0c/Kl8VMiQrEd/j6CudciP9VK/YFpbVY/zbt4+XVsqmGm5k5mF0PxcyfqA7ugYyW10srZThyz8L
cf5qCeIyNV/bjHnElSwf799m0qOoQoYxr99okRb90erOpD2rnAe/y8b+b/VbXExbJrHiGOJlRQ4sjoSLPbOZx4SsGpy4kIvvLpvm
BzRlfFGR9mRbTCjjC+vPfiswqaARAOYx7NsINKYrd8SgEQBWTQpgdfymU2mcDhoBYMOM4HYVe+kWZIMwH2uSkFXD6Z8TALoF2dwP
Gk9cyMWN5Eqes52wTTe0mylVUBc0AsDRMznQNnBMy68z2aDR2U54dsucUJXfJwRYeSgR7QkaB3ZzJMue9wPbGfr2ElvysXJCQN/l
hxINer9cNXOEF5k6zEvpiqAyl+6W47Pf8vHzdXZbWT79NZ93I6WSfLC8U4v3Im8XEUb0cSZn/m5cwVn2vF+7gkYAeGmIJz76MU/z
gXq2cWaI2qCxQU6wZH8iaNDIzktPeJDpw72UrggqczWhAp/9WsBof2JzX/9VyPsvuZKcWNkZ9pIH4ZOLnRBPRblc+vRiY9r7grG+
7QoaAWDiYHfs/zarXefQF84Hjt2DbcneBeGM3sRuJFdi7zdZJlHJkuKuEQ87kw0sVuJ+ul6Cdz5ONann3DP9XQmbDeLfXynS42i4
a0BXB1ZN4v+4Xcb5ghuzRnq3+0MNAHoE2yIhq0YHI9IfiVgQ9d7sxoAnPb8Oe7/O4rk6WKYpO/a3m6Uaz3ctsZJ38UYpYdv6qVaq
wNL9CaxuwyWbZoUMa36h1NonF/NxTcu2Q/7uYrJqYgD6dVJdXVLfhvZyQtdAG9KRW3UM6+1MFo/zZVyZ/fj5XJy6mN+ubK74zBre
6x+kkK3RLSclBnd3xJm/izGwmyMZP9Bd29Pf5+FkCQ9HS5JXWm+03+/kJzzJwG7q3zfWfZiC22kd9znI1qDujmTpc8wnm079ko+P
f85DportCEyk59fxVhxOIgcXR7T4+uDujvj0Yj56hdmRGSM0F8LRxF5igVBva5KYzb3JWU4Hjr3D7MjeheEay9+XVzdgxxcZ+Oqv
Qh5pM49MUcxNHeZJFj3DfN/f77fKsPJwEude2OpYCHiIHs18tREAzvxdLNXTcDjLQsDDShZFuCpqGvD6sZTj+htR+3XylxA2K83q
GLOXLFNvTA681FRM49WjyZDKFHCytfBXduyl2HJG51z9fpLnB8s75TItEFJXrzDpkvpzn/YhvcPsVH6/uEKGXV9mst78KbTgYfZT
3mTaMC9YCIz/0DzZ2wm3UquMPQyD6+QvIcvH+6NnCLMK9T9fL8Xmz9J1tv3np+slvISsmhZ7ZzsF2MDGSjD89cmBurgLAIC9jQXy
Sut1dj42oiLtybLn1V9XfPZbAb69ZJoZCYYW7GVFVoz3h7pWJs1duluODSfTVO5fZ+tKbDnvWmIl6RX64DXTyV8CkZCPt6YG6eIu
AADqJuuMiZujAvBIZ3uyPSZMY9D41Z+F2P5FBufL11Lct3y8P3lxiOYy301++a8US/YnmNwb/bgBboRNkYEbyZUaU/jM0ZQnPYmP
C/OCOGtPpHA6xUgk5GPDDOYr6ZrUSOU6O5c+jIpyIcN6Nxb0OHo25/5MvqogJatQuprJeWulirw52+NW75wXtqGHhnZQReUyzN8d
z2j/DBf1DrMjs0Z6qz3m3f+lgW0bq07+ErJxZojB01LVebSLA7Z+lmHsYRiMi53w4qJn/QaOjnJhdHxidg02f5qul4yun6+XoHng
6OMiwsqJAWd0WRiputY471edAyQaWwDdTqvCplNpJvkeYUj2EotVC8b6bnjuMTdGx6fn12H7Fxl6aY328/USNA8c7SUWWDHBn3jp
sJd6dR03P2M5GTj27+xA9i5U3yIgt1iK1z5I1jo9hqKaNKazhVxis3fJVINGAGDST6i5M/8U62kk3OXmYJk3+yn1F8zNfflnIes9
Poa27Dk/wqYsuCapuZws+AagsRryay82rlak5NZi15eZ9383An7bX1NdvQJsJh/Lqxs2Tn3v7sYxj7iSqcM8EejxYA9WjVSOawmV
OPtPMX78t8Rk29e4OlimbZkTCp6aZ/XFG6X46Tq7KtJLn/MjLw/1bO/wdC7Qw8ro6YyGMn6QO1k8zpfRPufqOjl2fJEBfVaejcts
m/LONKBlokYqN0p7Ay9nEdm3UH3l6sKyeizam3CuQU7T5dQZ84greeV5f9haa37O1tUrsPfrLHz4o/4qm8dltK2Q/ewAZgEtU+n5
de0r460nnAsce4XaapydOf1HATZ/mt6iQTNFacPXVUz2LQpn1RD25+uleMVE+yuNe9SNsOmDRQhw/mrJJ3ocEietmODvrinboUl2
kRTvfZLGvSvhZvp1sifjB7V/r1BzN1IqR+j0hDq0aWbI/Yu11e8ntfgeT0kklK9lCtvXfxXyvv6rEF0DbYhIyEdFTQNMoWCQJnwe
sHVOqL+6dOQaqRzrP0xl/N7g5yYmW6NDEerNrEqnMXg6i4yWzmgIgZ5WZO3kQHTXsFLe5NebpXjrw9Rfiypkg/Q5rsJy/T7mf95h
loauS5YWfOycF6Y23bBBTrBgTwKKK2TDDTg0k+LjIiJvTA5CnwjV6fLNXYktx5snUpBXot8JoMJymT5Pjyux5awzOQyFU4FjtyAb
sm9RBIQWyn/fNVI5lh9M6tB9BSnd6d/Zgbw3OwQSMfPqkueuFpvcnsbm2G7a/ju+AiWVsol6Gg4n9e/sQJ54yInx8a8cTASXJ7Hs
rC2i35oarNNzfvVnIapq5Wd1elIdmTXSm3QLaiz+c/C7bMRntgzkBErmA4or2ncRYG5FVRY843v/MVRl2+cZjN8bxg9yJ2tYVic2
hvZUGua6mNE+ZM4oZlkU5dUN2HgyDWf+YVd1UlvKsgB06cs/CvR6fmVefymQaJokWXcixWTT2A1h+nAvsvAZX0bHVtXKseWzdHxl
oOJ0+n7Onv6jUK/nbw/OBI6eziKyZ4HqQjjl1Q2Ysz2OvsgonZg2zIssGsfsDanJD1eKsOao6TblHRXlQrxZ7NkDGgPljubVFwMY
H7vjdAZiM7j9nvTWtKD9TFsZMXX8Qq5Oz6crnQMeFP9JyKpR2gdLoSRzlCaJPfBoFwcybZj6CaZ/EyvxOcPUxbenBZNRWqQdXokt
x79JlSgorUdBmQzWYj58XMToFWYLNpWO2RBZcvqlrJXuwbbkralBjPeTXrhWgrc/TjVo3Qg2e+7ZuplShb/ulBv0Fxs9ypuM7qf+
Of+/n/PwLW0Zp1Skn4S8NS0YIQz7tv9+qwzrTqTofWW8OX0+Z5Nyalm3CjEkTgSOIiEfO+eGwc5a+XDyS+sxa1uszioiUR3bhhkh
ZEQfZ1a3+fZSEV4/ZrpBI8B+tREALv5X2qHSVOeN8WG8uf3vuAocO6e/PRS6MPQhJ40l4Nm6eKMUqRysECq25Is3Niv+0zpFtUld
vbLIkYaOAODhZEnenaF5dXr9hymMzrVrXniLoifqVNbIceFaMX68XqL2Qv+Dc42FXd6dETKQafoaU7nF5pWmymaCtFaqwJsnUnDe
CBes+iyStPnTdL2dW5mnH3ElmqqWX0+qxJbPMjj3HsoFkwZ7kJUTlRa+Vmr9h6k4/Yf+9t+qos/n7BYDP2fZ4kTg+NpLgUTVh0tW
kRQzt9xFR9iwTumXh5Ml2R4TBnUNeJX56s9CrD2RYtLPv6G9nEjzAh5MXE+q7FBpqv7uYo0VJJtU1sjx2gfJ+XoeUrtIxIKoVTpO
D6yrV2DjyTSdnlNXXn0hsNb33of55k/TkZyjPLitredmpTou2DInVOUEbpP3z+QgLV/9JG6/TvbkvVmhjApZnP2nGN9dLsIft5lv
QSmqkA2avT0Wu+eHkwFdHZjeTCOuZw8wZSXie2yYEZLLtN9ock4tFuyJR46OWmywxbQVCFs/XCkyaBr5w+F2ZP0U9e0YCsrqsXhf
wmqFgk5WNWdpwce6KUGMJ/UzC+uwYHe8xvcifekZqp/n7O+3ynA51rAr5GwZPXAcFeVCVFXPKqmUIXp7LA0aqXYb0NWBbJgRAhsr
dntYTv9egLc+TjX559+cUex79128obkhujlpqsLJxJqjSSgoq2feu8UIFj3je8lZh+XsgcZeiFx8P368p+P91LArseX4+Kc8lWOs
lSryAbSoFCRSU/Wwo1j2vB/pEqB+X2NeaT0OfZ+t9vfPZF9SeXUDTlzIxek/Co+3p4XNysNJkT+82yNWFz1FE7PbVvY0Rb5uYrJr
XhiYThSev1qM14+lGLX670N6uAjPK63Hpk/SGbXY0YWmKsTqKAiw8nASqwrOHYGHoyXZOS8c4b7MshP+vFOGFYeS+lXXyS/reWgq
9dbDc7a0Uoa3Pkrl9IQ0YOTA0cPRkrz6gvKLteo6OWZtizVKCWXKfFgIeFj6nB954XH21/infsnHRjPordSvkz1huleguQvXSvQw
Gm4a1tuZPBzOLO3t9B8F+P0Wtwt0dQ20Ic8P1G0V1cM/ZLNuvWAIXs4i0lT8p6KmASuPJG1Sd3xtvXwxgJPNv8bVRsuGMrCbI5n8
hObCwJtOpUFVgGEl4ntsmhma+1g3B5W3r6qV48SFXJy4kGtVV69odz+XGqk87tTFfEQzLPqizq83y9p9DmN7tIsD2TSLecG3Iz9k
Y8/XbfcBG9LD4XZE10WJpDIF5u+KM2iAtmV2iL+m95FD32XhehJtIddcrzA7si06lPF78Mlf8rD5k3SeMRdsI3wlxNVBt3scmyrs
cn1CGjBy4Lh5TiisRMpnehfuTVCZakRRTHg5i8iWOaHo5M8uNRUAPvoxD1s+SzeL599UDYUulEnOqTVa2pKhScSCqFee92N0bEZB
HTZ/ms7p1hsCPg/vTA9W23+PrR//LcG+b4x7galK8wvlNe8no6yqYZW64ytr5KfQKnDUlJ5pzrxdRIz2Nf5xuwy//Ke8V6mns4js
mR+OYDUTVJ/+mo89X2XFVNQ0HNB+tG198XtBevQob+abolT45GI+tzcWaTB/rC+ZyWIf+6tHk/H9FeMXZ3m8p273YAPAikNJSDLg
9eOmWSFEU4uT60mVGlfrO5oZI7zIgrHMixS+83GqXvuJMqWP5+zrx5JxO800qnMb7dNy0mAP0jVQeVrMyV/ycC2hwiQeQIqbhvR0
IuunBrFqtdHkyJkc7Pkq0yyef5F+EtJXiwISP//XcVYbY0b7XGI6e7jiUBKnW28AwNRhnkSXG/d//LcErxzkZt/SBWN973+OfPF7
AeN9cjVSeYvWC/YSC/B5jalkHYmFgIftMWEa3yfrGxR4+6NUpd/rE2FHts4JU7mfMbdYilc/SMa/ifpZaSksqw/ILZYST4ZFrZS5
cK0EhWX1AboblWFtmRPKuIVQdZ0cC/bE6+33wYa1SBAxrDe7QnWaLD+YiF9vKp/g0Ie5T/sQTT9DZY0cyw8m/trR3l/UWT8liDz9
iCujY6UyBZbuT+RMKz5V2+u0tfZECs78zd0qqq0ZJXD0cLRUWekrr7Qeu77M5PSMPsVtayYFaN3sfN83WWY1Kzh1mHYvpd/MIG2L
iU7+EvLSE8wyQ7Z/kcH5dkA+LiJWM7iaXLhWguWHuBk09gqzI02Vgu+tBDPOx66okbfp2edgIzzVkYpBAcCK8f4qC9M19/6ZHKV7
WzVV7Tx+Phf7vsnS+/655NxatCdw3Pt1pg5HYzi21oKJu+eHn+yhYbWrSU6xFPN2xSM1jxvZXIvH+cY62epuH/brHyTjwr+GS6cf
0ceZzH5Kc5r06veTYMhWEVxmLRJEbI0Oje3XyZ7R8UUVMszbFdemH6+xzB/r265JqtY2nTJc70ldMUrguPQ5P4hVFCNY/2EK52f0
KW4K97Um704PUZsupc7O05n44FyOSb2A1fF1FWucCVWmskZudg3NVVmnoQJekz9ul+H4eW633gCAdVM1pxwy9cftMqw8ksTJn9nO
2iJ606zG1htyBcGKQ0lgs2euoroBHq36cHk6W07oSIHj0IecGE2wZRVJ8cHZls99Pq+xP+PIvspn3hOza/DaB8kGu9iTt2Mp58C3
WUarzNgens4isn9RBALcmWUXxGfWIHpnXLuKEelSJ3+JzvZhNxadScSFa4YLGkO8rAiTz4///ZzHqmKwOXOxE17cuzBiINMiOGn5
dZizPVaaX1qvv94XLAS4i8k0LSfjWyMEWPdhiskFjYARAscwH2vypIqL2Sux5QZv1EqZB7a58q1t/SwDH/7I/cCAjckMV9Ja+/NO
mW4HwlHThnmRUG/NH2BFFTK89kGy2oIrXPBUXxfSS0eV3n6/VYYl+xN4XC0Z/8704P0u9yrG7vsmi/VKcGVNQ5uveTmJcCetWjcD
5Dg/NzFZz3CSYePJNNQ3PFgxFAn52BodSh7t4qD0+D1fZeLIGcNOwNlosSUBANLz63DgO9PLMInwlZB9i8LBdLXuSmw5luxPjKyR
yuP0PDTG1r4cpLN92MsPJhq0cJe9xGLVnoURsLRQX405OacW27+g/RoBINDDiuxfHNFmwk6VmylVmLc7btK9PemcsHZKEAR83fw6
3ziejG8vGX+PsTYMHjjOfVp1W4CjZ3MMOBLKHHg5i8jGmSHoFqS+jLw6XNlwrUt21hbRY/oz2z/QWkcIHH1cRCR6NLNKjMsPJmos
uGJsttaCiUwL/Ghy9p9irOLoSiMAPNPf9X7vvqsJFXhfiyCloqZtL0d3J91WyeMqa5EgYu/CcJWF6Zr743ZZi9USGyvB8ENLIs8o
KziWmluLpQcTkZpr2DRIPg/ooqJegjqVNXIs2huvhxHpV//ODmRbTChEQmYtZK7ElmPOjjhOvZ6nPOnJKEVaE2PsfePxgC1zQjdo
CoDq6hVYsj8BsgZuTr4Z0kOhtmT3/HDGNSduplRh9vZYnVRe1pVxj7oRpinhmiw/mGjQlGpdM2jgGOptTVQ1pI3NqMaVOFoQh2Lu
xSEeZOEzvow/QJV583gKvv7L9FIFNBk3wHW/to/LX3fKz+l4OJzzxuQgRs+bPV+bRvn0pc/5n3TUwV4hrvct9XYRkVWTAgA09gJc
eThJq+dqVV3bwNHTSXf7Vrhs06yQWF9XzZlfCgXBpk8eFBp1sRdePrw0sm/r/oCENKbj7TidwTPGRfJj3RwJ2/c6qUyBmJ1xJpei
OuJhZ7JhZgjj4/+Oq8DCvQmc+hk9HC2JugUEpmqkcsTsjMeNZMO+P88Y7sWoddO7J9OQUWBazy99GNjNkeycF8b4+FupVYjZGdeP
S0Gjo63w2JJn2z8xK5UpsGhvAi7HmnZmpUEDxxeGqE6do6uNFFOuDpZpb00N8o+KZLa5WpU1R5PxAwfKkevDxMHapanGZ9aguEI2
XMfD4ZSn+rqQPgwqzV6Jq8CRH7ifxtYtyIY8o+XqchNCgN1fZeLoWW7v8d0WHXY/4F9xKFHr56qyVFVdVqLlqhkjvO6v1mry6a8F
yLx34evrKiaHlkS0KUBTUdOA5YeScMWIF0IvD2W/52j5oUSTKX3fZHQ/l/v9Spn4L7kSC/fGW+m7MBFbKyYEtGuyF2hslD5nRxwS
sgxbMKVHsC2ZO0bzlpgf/y3BN2Y4Ic3WkJ5OZGt0KOPj4zKrEbMzbkR1nfyyHofF2uJxvlNUVY1mqqpWjrm74nAzxbTed5QxWODo
YGOxUdXFTXWd3KCbminTNW6AG1kyzk9l6XemTD1VQJ0nHnIiTPcRtHY1oULHo+EWGyvBcCYpneXVDVh9JOkTAwyp3da9zKzAjzpr
3k/CmX+4XQ583ZQg0lRU4fAP2e3KUKmqbbviGOSpXVEtU9E30p7MY3DRCzR+Ju/7JisGaMwUOrgkos1+urjMaizck5BvzIbVI/o4
k4dY7OuVyhRYvC8Bl+6a1oz/2P6uZC2L13lcZjXm7Yrn1KoNADzaxYG0twdefmk9Zm2LNfhqnou98PL2mFBo2uKWV1qPN4+n9DPM
qLhraC8nsnk286CxsRBO3OqqWvlZPQ6Lte7BtmQMw7YhqpRWyjB7exwSs7lRGba9DBY4jo5yXanqe7/dKjPUMCgT5eMiImunBKF3
GPuehK0t2ptg0D5PhvbC49pfx91IqdLhSLhn5cSAM0xSOpcfSoQpVNicOcKLBLYj4GmQEyzZn4Dfb3G76t+4R93uf3j/l1yJ/d9k
tWu8ygJHbxcRLC34LQrBmAsvZxHZFq35orfJoe+zUVHTcKBLgA05uCSizd6k078XYP1Hxk1pdnOwzFt9L22ZiapaOWJ2xplcxehn
B7iR118KZHx8ZmEdonfEbeLaqo1IyMdrLH4OZVLzajF7e1y6oXtuWlrwsWdBeF9Nnx0K0jgpzbXH3tDYplQXlNVj9rbY/PLqho16
HJZWXnsxoF23zymWYta2WGQXSU3qfUcdgwWOT/ZW3Zz2l/9KDTUMysRYCHiYOsyLzBrp1e70lvoGBRbsjjfrvbThvtasZuBbu5Vq
voHjo10cCJPGvUd+yMbfJvAc8XERkVkMeoips2hvAmeaKqsS6Schb0xuvOAsr27AKwfa30hb2R5HAAjytCJc79WpjR1zwxgXpsgp
luL4+Vxer1BbsndhRJvWWRtOpuGTi/lGfYxEQj52zw93t7NmdgmTV1KPubvikGLgwj3t9fxjbuTVF9kFW4v2JnCymNeMEV5aZ8IA
wN30asTsjFttjODi9ZcCSYRv24JQrR38LsvkJiZ0bUQfZ7JhBvOgEQCW7E+AMTMXVJn8hCejyuuqpOTWYvb22CtF5bIoHQ7L6AwS
OLo7WtZ1VVP17PdbpbppjEKZlW5BNuTNyUFa92VsTipTYN6ueFxN4H5A0B4TGPRlU6WoQobcYvOZFWtOIhZEvTlZ8wXYv4mV2PN1
+1azDGXtFGYFfpSplSowb3cc/k3kduEfe4nFqu1zHxRWWHEoUSeNtGUqVhWDvKwQl2leLTneeCmQVQXLrZ9loG+kPdk1L6zF80sq
U+CVg4lGX52WiAVR22PCLjHtBXclrgLLDybGVNQ0HNDz0HRqzCOurIPGV48mczI49nERkdntmOS6nlSJ+bvj+xljJW9sf1cyup/m
CcebKVU4aIKtXXTpiYecWAeNm06l404a9ybrXOyEF+eN0b6IU2xGNaJ3GGeiQ98MEjgO6u6oslxdZkEdaqWKPEOMgzINErEgat4Y
n0vtSblsrrpOjrm7DF99zdBEQj6GP6y8RyoTN5IrdTgablk1MeCSq4P62e6Kmgasfj9JaqAhtcuIh52JtmnblTVyzNoWy7r3oTG8
N/tB2ftD37dvX2NzDSqqfwab2T7HUVEuZNwAN8bHX0+qRFVtAw4uiWzx9aIKGebvijf6c8bXVUx2Lwhn3PT+2Llc7Dhten30RvRx
ZtRcvrkv/yzE9xwt9rb6hQCtb/vz9VIsPWCcyrC+bmLCJB1a1kDw6tFk/Q+IwwZ2cyRb5jDf0wgAP10vwclf8jj5nF36nN/A1tkW
TF26W44l+xM41U5ElwwSOKqrYJiaZ5aPK6WlkX1dyOJxvnDTcJHPVHl1A2Zvj0V8pnlsSlZn2MPOxFqkfdGgm2a6v3FQd0dGM8bL
DyUhv7Se86U1ba0FE1dODNDqtkXlMszaHmvwXnvaWDTOl/S999nxX3IlDnyru5VgmVx54BjibT6BY7CXFau9cQBw4VoJds4Lb/G1
vNJ6zNhy1+h7dHqF2ZHtMaFgkp5aWinDug9TcfGG6e1lH9zDkbwzjXn1VKCxGM47HG2jM7CbI+nf2UGr2371ZyHWfZhilJ9LJORj
59wwhm2bMpFZ2HFbb/SNtGcdNKbl12HN+8mcfMx6BNuSkX01XzMoc+FaCVYeSeIp2rufgsMMEjiqmxlPL6g1xBAojgv0sCJvvhwI
XTVYBRoveGZti71fUt7cjW1n5a/YDPNK0QMa003WT9U8c3/gu2yjthRgY9EzficdbNi/decUSzF9813kldZz/ud8vKcjmTbMC0Bj
ELDsQOI5XX4Oq2pRYC6VVa1EfI/mrUuYSMmtxYKxvi32NKbn12HmtliDFyNp7cUhHmT5eH9Gx379VyE2f5o+gmvVGZl4tIsD2R7D
vOcdAJRVNWDhnoT8BhWTIca2fAKz31tre77KxJEzxmsPtGKCP2HyfnAnrRofXsjl/HuqvvQItiW75oVBaMH8Iaiuk2PB7niV78PG
tkbLFfIPzuVg5+lMs38u6D1wDPW2JvYS1XeTRlccOzQbK8HwReP8zjz/GPN0KiaMVX3NWHzdxO0qigMA8Zk1q3U0HM54Z0bIQE0r
FJfulut0NUufugXZkOe0eK0kZNUgekfcJ6ZQKTbQw4q8M+3BPpllB7Xv16gKUXGN7esqhkjI5+wFDVPrpwTn+jNM52zS+iI5Na8W
M7bEGvU5E+xlRda+HAR1NRKa5BZLsfbDVJOZAGqtc4CEVc87oLHg29xdcZwsLAIAs0Z6Ex8XlTuVlCIEWPdhCr7603h9EB/v6Uie
ZZDiLWsgWHUkCWa8uKRWsJcV2bswnNUElUJBsHBvAmdXaCcOdme1J7zJ5k/T8fFP3Ey71TW9B44Rfup/Aab+AU1p75n+rmTxs35Q
N7Ggjbvp1ZizI3ZSZY38lE5PzGHtXW0sKpfB3DZxT37C836qoyp5JfVYfihxhIGG1C58Pg9vTGbfs/F2WhXmbI8zSmEJtqxFgojt
c8NgJWq8ENn8abpeCvg0nV+ZYC8rcjed+/s/VZk02IMM7aW6ijkTidk1mLk11miFHQLcxWTmSG+MYlAFGQAOfJuFD87l8kz1eiLQ
w4ocXBzJutjVm8dSwNXnqoejJdGmuMgbx5Lx7WXj7dV0d7SsWz+FWarw4R+yORsA6ZuXs4gcWRrJuFpzkw0n03CNo0UKHW2FxxY+
w6zXbXNcqDRtSHoPHIM91QeOvA7zUFNNOvlLyGsvBqKTv+by1mxdTajAwj0JkTVSeZzOT85hzzzavsAxPsu80lRDvKzIsuf9NB63
9EACTCWlbfITHiSEZYXhP26XYdmBRJO5oH5nenBsU+GTs/8U620GV13RgzAfa9xNN83XQ68wO7JyonapgU2MGTT2DLElLw7xwBMP
MQt8f75eiq2fpxt9/2V7eDhakoNLImBjxe4C/MMfc3Hmn2LO/txsK8ICjf1zL1wrMdrPxOMBW+aEipj8LjIK6vC+EVNpjcleYrHq
wOIIMOmJ3NxXfxbis98KOPuYLX3WbwrbOhFrTxh3ddwY9B44aio2YMG0IzFl8jwcLcnCZ3wxoo+LXiYMfrtZhqUHEnhc3euhL30j
7YkTyzfw1pKyzWevsUjIx9ZozfuE3j2ZxtnZ+tbcHS3r5j7Nbvb+p+slWHEoiSc3kTyqacO8yOAejgAag5e1J1L0tuHQSs3FAdM2
D1zj4WRJtrFMdWzNWEHjyL4u5MXHPdA5gNlk4t30auz5OhN/3THNtNQmErEgat+iCNbF4JJzarH1M+5Wix3U3ZEM6OrA6jaL9yUY
vZjRjOFehElaNNDY+sRU3lt1SSTkY/+iiA1+buxS4bOLpNj0SRpnW+/1CrVlVESvuTVHk/EDRysZ65PeA0dPJ/X57TwaOJo9W2vB
xFkjvU++PFR/7xlf/lmIdSeMU33N2Eb20b4FR5PUPPMJHJc+50c07e86808xPjWh1JI3JweJ2KSx/fhvCVYcSuSZynXNw+F2ZNG4
xhShyho5Fu9LgD5LmVupWXFsT8NnYxEJ+dg1L7xdaf+GDho9nUXk2QFueP4xN8bjjs2oxsHvso0eYOjKljmhl7QpyLTicKIeRqMb
Yku+mEkLi+YW7Ik3en/QTv4SMn8sszTFz34rwK3UKrN4DrL1zvRgok222Or3kzjdeu91lttAVh5Owrmr3F3x1ye9B45OturvwpZl
egZlOiwEPEwc7E5mjfTW+T7G5g7/kI29JtK0XdcsBDy0dz8TABSWyXQwGuMb2M2RTBjkrvaYzII6rNPjapauDe3lRB7pbM/4+Et3
y7HycJLJBI3ujpZ1zYuCrDicqPfUQ3UrPJF+uk+h14U+EXbkbxV9LNdNCdKqoEOTzMI6zN4ed9wQQeOIh53JmP6uiIpk/py+nlSJ
4+dzzSZgBBp/Z/06MX8Mmuz/NgvJOdxtpxMz2qfW3ZHZCmp9gwIL9yTgMgcKGjHtm1lSKcOOLzL66Xk4nDR/rC9hmkbe3Ec/5uFm
CncD7ZkjvAjT3rByBcHyQ4n4+br5vBexpdfAkccDHGzUp9C52LcvxY7ipmG9ncmCZ3zBtqIaGwoCrDdy9TVjG9jNsV29G5sUltfr
YDTG5eksIhtmqi9qUFevwEI9r2bpkrVIELFyQgDj4y/HliNmZxynXg8eTpakT4Q9ugXaQMAHridXIS2v9v6FxNboUFFT5dvdX2Xi
0l39X0R6q3lfkogFcHe0rONST8+hvZzI5tmhuJpQQZbuT4ypqGk40PS9KU96kuEPa591UFBWj1lbY1FaKZuqi7G2ZmMlGD6gi8OZ
wT0c0b+LA6tiGt/8VYiPfspDQpZ59eGdONidjNGioFlqXi0OfpfN2ccizMeaTHmSWWaRVKbAgj3xUDUZYkjTh3sRppkGO09nwhQK
jTVnZ20RfWBxxP6U3Frs+SpTq5ZMI/u6kJkjvFjfd15JPXZ/xd0WFb6uYjLrKW/Gx79yMBG//MfNoDF6tA+Jy6jW+wSbXgNHa5Eg
StNeNhc73TR6p7ihXyd7smCsr14K3zRXV6/A8kOJRk9vMbb2XDA2V1guO66TExlJU7NmTUH02hMpSM3l7mx9a4vG+cYynVy7eKMU
i/clcOZn83ERkeUT/DGwm2OLrz/zaGOZ+8yCOpJZKEWXgMY9Rb/8V2qwYhO+rupjwmAvK1F+KTcmUx7t4kA2z25ckQ30sILYkr+2
ogYHgMZ9OUue1VwESpWyqgbM3har896egZ5WZGA3Bwzo6oheLNsEJefU4ptLhTj9R4FZVsZ+ONyOrJoYoNVt3zyeotvB6JCvm5js
WxTB+PiFHAkavZxFJGY0s/3jd9Kq8fVfpjVRbWMlGH5wScT+SD8JhBY8lFQ2sB5/5wAJeXc6s0qzra3/KIWz3RNc7IQX9y+OYFzN
mAv7cFWZ+7QPmX0vAJ61LZb8E6+/15ZeA0cmszKezjRwNAcDuzmS2U95My5u0B7l1Q2YuysOd9JMo7CJvliLBBG6SFMFoLfVBkN5
7aVAjal6H/2Yh7McrkLYWpcAGzJ+oPq02yYXb5Ri2YFEzvxsMaN9yJxR6mdxfd3E8L1XYCGjoA6vfZBssPQvdSuOQGNPw7/ulBto
NKo9FGp7v7dfXb0CMTsf9OxzsRdeZlIESp2lBxKQlq99OwFnO+FZO4nFMAeJBcJ9rdEzxBa9Qu1YZxIVlNXj7D/FOPN3MWIzzON9
PdDDiqyY4I9lBxLvV/l2shWe2jJHuwJGZ/4p5my6X1NrBhc7zb93uYJg0d4EXOFA0AgA70wPZty8ft2H3A3clbEWCSIOL408E+kn
QY1UjgV74lHfwC6Is7ESDN8Ro937zB+3yzhbwMrFTnjxg+WdBjLJilMQYPWRJM4GjS8O8bgfNH5yMR/6DBoBA+xxrJUq1PbMas++
DMr4nuztTGaO8DLY7zGrSIqYnXHILOiYvZOae6SzfawuzlNcYdr7G18e6klGa+j39k98BbZ8lm5Sz5m3pgUxqj78x+0yzqw0ioR8
7JgbxnrvVnWd3GDpX35uYqKuHQcABHsZ/3Mp0k9C9ix40Fx79ftJLVI2t0WH9XWw0f4jfP1HqUp7ZD7Z25kM7eWEzv4SeDnrb6tB
dZ0c56+V4MzfRZxYedIlT2cRObiksVrqtpjQ2Ogdjenj22NCJ2iz318qU2DrZ+lXdD5QHXC0FR47siwSTPc1rjiUhD9ucyNT6PnH
3EjPEGYr4t9dLjKplGlrkSDiwOKI2KY922veT0ZeCfvMgs2zQ8+4sqz622TTqXStbqdvNlaC4YeXRg70ZVgZdu2JFM4Wwhnb35Us
H9/YguluejU2nEzT+zj1HjhWS+VqA0drkQC+bmJCAwHTwecBw/s05rtrUxFOW3fTqxGzM85oTam55tEuDjo5j8JUqqgo8Uhne7JY
Q6peXmk9XjmYuNpAQ9KJeWN8SKCH5tdWQlYNlh9K5EyJ87enBWtV8CPST4KRfV2IIUqb94mw03gM236ZuhboaUUOL428n3q943RG
i301qyYGkG5BzNoGKPPpr/k4/XvLfmpOtsJTO+aGTWjPeZk4f7UYZ68Wm21xCSdb4alDix+02Pjh72IAwPLx/qR7MLu03SafXMxH
UbksSmeD1BGJWBB1YFHEFKYTDK8eTcZP143Xp7E5NwfLvCXPMUvzVhDgwLdZeh6R7txbaYxtygD74FyOVqtl0aO8tXo/Bxor3WcW
cu+6XiTkY++C8DOBDK9d3z2Zhm84mp48tr8rWftyY1GnipoGLN2fYJD71XvgWFIh05i+0MlPgswCk6hV0eGN7e9KZo701mvRG2V+
vVmKlYeTrEylqIkhsKm0qY6cm9sPNAr0tCKbZ4dCXUcfqUyBhXviYUqTDWE+1mTWSM2b9UsrZVi4J54zJc5H9nUh7UmdfqKnE364
UqTDESn3cLjmwDHYiIFjoIcVObI08n5D+K//KsSxc7n3n+UjHnYmEwczS2FW5lpiJd79X9tZ6a3RoXoJGm8kV+KfhEr8E1eO/5Kr
eFzd76QLttaCiQcWR0xoWsk4cSEX3/xVyBvYzZG8OMRD6/MePZuzSVdj1KUdc8MuMe17uuvLTHzPoZ53b0wOdGdaWO77y0XI0nOl
Z12RiAVRh5dGXmqqM3E1oQI7T7MvTtMrzI5EM9z7qczB77gZaL83O4TxBM4H53I427brhcc9yIoJ/vf/v/xgos73qqui98CxrKpB
4zFDejri3NVifQ+F0pJIyMczj7qS6cO9WDcq1oVj53Kx4zR3mx0bQ5iPNdHV74IQ01txtLO2iN4zP1xjhcY3j6eYVHqRgM/Dxpkh
Go+rrJFjph6KmrTHwmeY9UBTJcTbMMFa3wjNEy7WIgGcbIWnSiplEw0wpPsCPa3I+8si4WTbONn6d1wF3jz+oD9tqLc1WcuwbYAy
+aX1WHYgoU0QMqy3M+OUPU3KqxsQl1GNS7HlSMiqgVDAh521AMFe1ugRYkt4PB7kcoLcEikyCuqQUVC3qayqYZVO7tyI7CUWqw4u
idjQtG3jt5tl2PZ5Bs/O2iL6jcmBWp/3ox/zwMXHZ8fcMMJkEgYATv9egKNnDVP4iomhvZwI04wdhYJwNghqzc7aIvrw0sj9TcF8
TrEUi/YmsN47biXie7w9Vfv3ma//KtQqLVbf3pkeTFoXa1Pl3NVirQJuQ5j9lDeZ+/SDoH7b5xkG3TOs98CxvFpz4DiwuyOEFjzI
GkzvAtacWYn4HuMHuudOHurJaNO7rtU3KLD6CHdSW7hkQFcHnZ3L1DJVLQQ87FkQvl9TgRNTK4YDANOGeRIm6d8L98ZzqpfbxMHu
xIPhHidVdNFWRpNO/hLCdF+gv7t4giEDx2AvK3L0lU73e95mFNRhyf4HF3221oKJO+aGMa4AqMyS/QlKgxBterOpYi+xQN9Ie/Rl
3qdxZWZB3coz/xTj45/yTHIrgqOt8NjhpZFTmlKck3JqsfJIYwr52peD9ju34/Pz4585kVDQwlvTgsmg7swuwP+4XYb1H6Vy5r2K
bYuj768Um8Rqo5Ot8NSBxRETmiYuquvkmLMjTqu948vH++d6tmN/84cXcrW+rb6smhhAnuqrvhZCk+tJlVh5OImTv/Mlz/q1aHnz
9V+FOHEh16Bj1f4TiKHSSs2FN0RCPob0dDKxy1fzZWMlGD59uBc5u6Fn7pJn/YwSNBaW1ePljXdp0KjCI50ddHYuazV7kLnoranB
Gvd3mWIxnCBPKxLztObUoNXvJ+F6UtuiJsY0cwTzPliqFFXov/3Fk72Yt6/xZ9gQWhdCWgWN5dUNiNnZ8qLvvVmhJzVNlqiz/qNU
3E1XXrGUTW9FffB1E2P2U944u6HnhpF9XUzqWsDZTnj26LIHQWNOsRTR22N/rZUq8kb0cSaP92QWYClz8UYpcou5FbSsnOivsRhZ
k8yCOqw8nGSwaslMzBvjw7jFESHAkTPZeh5R+3k4WpKPVne+HzQqFAQL9yZoVUTw0S4OZNy9lknauJZQgSQOTWoCjVW+mab3F5TV
Y8n+tlkZXLB8vH+LoPFaQsuMFEPR+4pjKYNUVQB4eagnzv5D01WNydNZRJ5/zA0TB7sbZPZflZspVVi0L+G4qbeI0BeRkM+6N5o6
jraGnxjQ1qZZIWRYb/UX/3klplcMh8/nYcOMEAjUbdhEY8rXmb+5tYr6/GNuhG37BWVup1brYDTqPdmb+cqaoQLHMB9rcnhp5P2g
USprbLuR3WyVY94YH62LVACN+xpbF8NprpjBBK8hWIn4eHd6MFzshMTQs+jacHWwTHt/WaS/3709jaWVMszZHoeiCtkgR1vhsTWT
tE9RBYDPfyvQxTB1ZuEzvmTSYOZ7NZfsTzBYtWQmfFxEZBKL/cG/3ixFejva1RiCr5uYfPBKpxYtcNZ9mIprCexTFyViQVRTsRVt
ff47t56zU4d5amwN1dyyA4mcTA1fMymAjB/04LmbWViHJfsTY4wxFr0HjoXlzGaRO/lL0DXQhtxK5WafInM2tJcTee4xd/RlUG1Q
3776sxBrTxh+BsWUdAmQ6HxG3sdFRLiejrNxpuagUSpTYOFe0yqGAwCTn/AgmopM5BZLsfmzdM5UUG0yfYSXTs7z261SnZxHlU7+
EsKmvYS3HltRNInwlZBDSyNgZ/3go3juzrgWK4ODezgyKpakzlsa+s999WchmK4iGcLS5/wQn1lNuNLrTxlfVzE5vCwSTSnaNdLG
1MCmSpILn/GdYmut/QRsYVk9Z9pWAMDMkd5k+nDmr/W1J1I4t/L02kuB4GuYnGvu6NkcPY6m/SJ8JeTgkgg0b/Fy5EwOvtayCuic
Ud6X2jMJWFkj59TE5viB7mTxOGaVcwFg62cZ4GIM8ubLQeSZ/q73/19dJ8f83fGoqGk4YIzx6D1HLTW3lvGxC8a2r7gCxVyAu5gs
H+9Pftvei2yeHcqJoPG9T9Jp0MjAQ6G6/125tXN/mr5tnh1Khj+sOc3wjWOmVQwHaExTnD9G/XsfIcCKw0mcqaDaZOIgd+Lp1P4A
q7CsHr/d1O9FMtv0Kw8d/Fzq9Ai2Je+/EtkiaFy8LwHXmvVWDPK0Iu9O11wsSZ0D32UjTcOqybWECt6Xfxa26350bdXEAGMPQaUA
dzH5YHmn+0GjVKbA/N3x9997OvlLWlzoaeOn6/qdSGHjpSc8yPwxzCtsnrtajK/+5FYLg8HdHUkU8323yCqS4mYK94KIJn0j7cmx
FZ1aBI1n/inGnq+0K+gS6GFFXh7avnlJfU/+sTG2vytZ80IA4+P/vFOGD3/kXpbD5tmhbd5LFu1NMOpKuN5XHJNyalcD2MDk2D4R
dni8pyMx1/5OxiYS8vFkLyfy7GNu6KFlPyl9KKtqwLIDLS+YKNUe0mGaapNO/hL8m1ip8/PqwtboUDKkp+YUwx2nMzjbpFcVkZCP
92aHQmihfthHz+Zwbia0S4ANeWW8v+YDGThxQb/xsEQsiBrFckXN00l/kyl9I+zIrvnh9wvdEAKseT+pRa81O2uL6F3zw9X2QdYk
v7QeB77NYvS8WXcihRefWU1mjvRmtK+9uEKGwvJ6FJTKkF9Wj+IKGSwEPAzr5QSmjbXVCfS0Qr9O9uTS3XJOPe9bpxZX18kxb1c8
/ktu/Pzi8YD2pvsBwN/x5e0+hy6MG+BGXnme+eu8pFKGtz5KHaHHIbEmEQuiNjCoVt3cN39xayKluZF9XcjbU4NarJ7+drMMrx5N
1vq18ubL7UurBhqrQHPBsN7O5I3JzF+DVbVyvP5Byid6HBJrIiEfexaEt6lcvPr9JFzVIg1ZlwxRVXVjcYVsA9OqYivGB+BKbEUU
l/LiTV2otzV5fqAbRkW5GHXvojK306qwZH9iemFZfYCxx2IqugfrvtfaY10d8dGPnFrMgtiSL94yJ7SWSdn0T3/Nb9HrzlTEjPbR
WEU1s7AOu7WcRdaXqEh7smNuGCwE7R9WcYUMn/6q315ZT/dzvSS2ZBeAueqp9dDjPR3JtuiwFl/beCoNZ1pVAH5vdsj+9vbL3XE6
g9Xxp37J5536JR+jo1xIv072cHe0RIOc3AsSZUgvqENcRrXKIjsAsOerTKx5IYCMH6h9r8kmfSPscekuNwIoAHg43I7snBd2/3O0
vLoBc7bHIS7zweMxKsqFNBUpaY8rsRVGLyozboAbeeMldgHF+g9TUVUrP6unIbHmYie8+NHqLgPZvv6/N0BPWW1MH+5FWrc+up5U
iYV747V+Dx3U3ZHoYjHhSpzxX6vDejuTTbPYTRJs/jQdhm69pI69xGLV7vnhG1oXATzyQzYnUoH1HjgCQEpuLZgGjh5Oltg5L+zS
zK2xRn9wTJnYki8eFeVS+0x/N3QOkBh7OEqd/CUPm06ZVuVLYwv1tib6CP77RNhBIhZwZsLG2U54ds+C8GGRfpqfuxdvlCptaM51
od7WZOowzalBb3+UaoDRMDdhkDtZPSlAZ+d766NU6Lsp/KTHtQtiPBwtiS57ZY6OciFvTQtu8bX932bhk1ZNpheP82OVVqfMnbRq
rS8yvr1cxPv2svYXzu/+L433WFdH4tHOVVtnHRRd0pVRUS7k7Wa/u6IKGWZuudsmDXiehrRzJjIL6oxeVGbMI66sg8YL/5a0WDU3
tgB3MTmw5ME+VKbiMqtbFKfiiremBpPR/VpmTsRn1mDBnvh2rfDqYptYeXWD0Xs3PvGQE+ug8UpchdZ7QvXBy1lEDi6OaJO1ce5q
MfZ8zSx7RN8MEjjGZVaDaaNYAOgdZoeNM0PIqiPc7KPCZZ0DJOTZR90woo9Lu1Kc9EkqU2Ddh6n44UoR/f2yFOylvybpw3o7Xzr9
h+rKi4bSOUBCtkaHMfqwv5NWzdl+S+rweMA6Bo3cL1wrMWhjX3WEFjy8OTmIsE35VOfCNf1faI6OciF+WqZO2lpbIK9UN21Clo/3
Jy8OaVmR8uQveTj4XXaLn39ITydGEwqabPokrd3naI+/7pRh3ADty/oDgLRevxMKTM0a6U3mNdvjl1lQh1nbYtF6UmHCoPb3MwWA
uMyadp+jPUb3cyFM3p9a2/d1lh5Go52eIbZkz4JwrVrNXEvg1rYNO2uL6N3zw/Z3b7UqmFUkRczOuE/as8I7sq8L0cV1RWyG/qti
qzOkpxPZMieU9e12f5mph9FoJ9JPQvYvikDrXsNXEyo4dZ1jkMDx77gKTH6C3Qfh8IedoVAQ8toHyTxTa1BuSHwe0C3Ilgzu4YhB
3R0N2ntMG9lFUszfE4/UXG5VWzMV+gwc543xwfdXivS++qOKhYCHmNE+ZNowT0aV73KLpZi3O26TscbbHs/0dyOd/DWvpu76ihsf
ak62wlO754dP0GX2Ql5pPd7+OFXvbVPaswKki/6GznbCs9tjwoa1Tjv64FwOdp5umYLs7y5usaqlrbP/FBu9sEe1VN7uc8RlGvdi
FGhsdt+84mxSTi1mb4v9pHVqm0jIx+yn2t/PFADySqU6OY82pg3zIovGsX/NXLxRitQ8bnyuj+zrQt6drv3riCt79QAg0NOK7JoX
Bl/Xltd2ReUyzNoW2+4Uy3kMegczkVei/z68qmiTUg00tim6ncaN2gGDujuSDTNC2iz4xGZUY+GehEgjDUspgwSO1xIqIwHEsr3d
yL4u4PN5dOVRiUHdHcmg7o54vKdji6p8XPb7rTKsfj9pBJf2P5iaAA/9BY7OdkK89IQHef9MjsFfb538JeStqcGMA+PKGjlm74jj
ZL8lTWysBMNb71FR5kpsuVYNnHUtwldC9iwIhy56NTaRyhSYtytO721TxvZ3bVe6pI1V+wLH7sG2ZFt0aJutGjtOZ7TZkyu25It3
zA1rd6ZIg5xgJwdm0du7Z0quILhwrcRo/Vhd7IWXd80L79t8guduejXm7IidVFkjP9X6+DH9XQnTLTmalFYy63+ta8ue9yNsJ/mb
HDuXq+PRaGfBWF8yo50tgv5Nqpiko+G0y6DujmTjzBC03p9ZXt2AWdtikVvcvnTaEX2ciXc791E3Ka0yTi/Y1tkAbBw7x412KzNH
eJH5StKFMwvqELMzblONVB5nhGGpZJCIo0Yqj/svuVKrD5LhDzvD311MFu9LkOaX1nN7OU2PXOyFlx/r5tj3sa4O6NfJ/n41PlOx
9+ssHP4h2+gXwaYuREMhlfZaMNYX15Mqyb8GrHC78BlfVv3BAGDBnnhOBFXaiBntc6Z1Kooy56+VGGA06g3q7kg2zQpp836Tnl/X
ruyGtcdTkKznHm9iS764vbPp7VlxnDHCiyjbO7T+w1QoSwlf+3JQbaAOJoaOn89t9wVle3UOkJCuge0r4vXlH4VG68faNdCG7Jgb
1iLgv5pQgYV7EiJVXcTpohhQE2NkUbw9LVjrNPS80vr7VWWNRSIWRG2aFXKJSTE1dcqrG6BsYsDQYkb7KG1cXyOVI2ZnnE5Wd59/
TJfPWcOnBq6ZFEDGD9LuZ6iuk+P3W8btkyoS8vHm5EAysm/b111BWT1mbouVcnFy3GBLVZdjK7SegYz0k+CzN7qKNn+aTr691HH2
xfUKtSX9uzjg0S4O0EWVNmMoLKvHisNJuJ5EW23oQqCeA0cA2D0/HDO2xJLmlQJ1zVokiBg3wDV2ylBP1tUrlx9KNPpFirYCPa3a
7HNT5bdbZel6Ho5aS571I1OebLv6EJtRjd9ulkHZRQ0Tp/8oaFNBVB+mPOlZ297KqAItqsa6OVjmvTsj2L13WNt9/SsOJ+G8kpYx
4x51Y9SnVJOSShkO/5Ct/zcJDV57sX2l/QvL6rHjdIZRWjpMHOxOWveQvHijFIv3Jah8MvQItiUhOtxGYMiJYZGQj63RoaQ9Adc/
Rk7tfDjcjrw1NRjtLcYEGDflEgAcbCw2bo8JW9kzpO31slSmQPSOOLVVjZkK9rIiumztJRIa9iN58+xQMrSX5jZdqvwTb9znbLcg
G/LOtGClrYvKqhowe1ssuLpYZrDA8cK1YkRreaEBAHbWFnhrajCeHeBG3v1fmsk1+WbCy1lEHulsj/6dHRAVac/Z4jZMXbpbjlVH
klYba9bY3DjYWBjkcZSIBTi4JAKHvs8m31wqVJqWpS0XO+HFl5/0HPjsADetVnM2nEzDhWslJvvaf3Myswvq/NJ6GKtFjb3EYtW2
6NANvZQEPhkFdYjeEbd63tM+jHrzthafWYP1H6bq/ffnYi+8zHYVW5kGObtZ9KG9nMjal4PaPLelMgWWHUjEH7fbznAHeVqRlRN1
0w9z79dZqKtX1OnkZFp6Z3owYVINWZ31Hxm+pYONlWD4hhkhZwZ0dWjx9WPncrHzywy1z9nnB7avCFBrrg6GqSbr6mCZtnt+mH+E
b/t+X/8kGOciXCTkY+Ezvown45gwVsol0BgAb5wZorILwZL9CTrbu6zL1UYAcLXXX9/b5hxsLDbunBu2snWhILaMGTiqS6cuqZRh
xpbYNtWaucRggWNyTi3vVmpVu9NXegTb4tPXu+L3W2XkxIVc/BPPjYqD2nCyFZ7qG2k34eEwO/SNtIeucs25YNeXmTh61vB75cyZ
g8RipaHuy15igeXj/bF8vP/Jz38rOHn+WjH+1rK6p7VIENEnwi52cA9HjHnEVesxHfwuu03bAlMyuAfzXllZRcYpjtEr1JZsnBmi
dBU4q0iK6Zvv/lpe3bDRyU7IOnCsrpNj2YEEnYxTkzWTAvvqYtWmnmHKoLOd8Owr4/2HjVCyati6QXxzViK+x/aYMJ2sMCVm1+CL
341bFXnxOD/ylJK0KzZOXMg1eApZJ38J2R4TBvdWFVHfOJ6CbxiU6h/U3VGn4wn11n+GUbcgG7JrXnibCo5NaqRyxn2fC3RUeZiN
MB9rsnVOqNIVGwBQkMbigWwZo9e1hYCH+WN8yctPeiods4IAyw4k4K875Tp7XTzZW/vVOmUM8ZwN97Umu+eHw01FJkl1nZzxhHRB
meGfs35uYrJpVghUTayVVTVgxtZYzhSZUsWgVVVO/16A9gaOTQZ0dcCArg5Iy68j5/4pxpm/izgdoQOAo63wWPcgmylRkfboFWZr
kBeaoeWV1GPZwQTcSdNfmmNH5WhrnJ5mzz3mhucec0NFTQO5EluBW6lVuJNejfwSKbKa9bqysRIMd7ETnnGxt0SwlxVCvK0R7mON
1tUktfHZbwXY/y03ehhpa+mzfoyPZRqw6NK8MT5k1kjlWSFFFTLM2R6LogrZIEC7VLrXjyW3eL7oyxMPOZHHe+rmQl5B1K848njA
+IHuZMFYX6WFdHKKpZizI07lfty3pwXn6qoS9nufGDWzWWVqMxs/Xy/Fts/Vr+7pWvQobxI9uuVe2MoaORbtiweTvd79OtkTXVTf
bU5X10mqPP2IK1mvpt3Gxz/lgc0qnqGzoyY/4UmWPa/6/bSsqkFlQKyJtY5/l5qEeFmRjbNCoS7Ved2JFPzyn+7aFnUJsCFOOr6e
CPe1hq21YKK+9oc+8ZATeXtacJtCQU0++jEPLz3B5jlr2N/zc4+5EXUp/KWVMkzfGmsSHQcMGjievVrsuWJCQK4u32QC3MWYM8ob
c0Z5IzG7hvx8vRS//FcKfe7PYsLGSjC8S4DNmS6BNujsL0HnAInKWRJz8evNUrz2QbJOUxupB7T9INQVO2sLDO3lhFb7CvS+I/78
1WK887H+0xv1acwjrkTVzLgyuv5QV8fPrbEFhKoAv6hChhlb7rZoiM1j+dv47LcC/Hxd/43B7awtoldNCtDZ+arrVAfwnfwl5NUX
AqGqRcm1xEos2ZcQU1HTcEDZ9196woMM6ambWf9fb5YaNfsmerRPu4PGmylVWP2+4Sqo+7mJyYYZIW1+f8k5tVi4N55xA/iB3XS7
2gg0TswM6OpA9LHyqqly6qZT6egTwbzvNqCbtjVMONhYbNwwI2Rlv072Ko/JLZbiTno1nnhIu9eWn5sIlhZ81Dfod/JOaMHDrJHe
ZNowLwgtlP+aFQRY834Szup4T/jA7g66PN19A7o6nvzhSpHOr/+iR/sQdVvd9n2TBR+WGXsSAwWONlaC4eunBJ9RN5lZVCHDLBNY
aWxi0CvRWqki7/QfBaxmstgI9bZGqLc15ozyRo1UTpKya5FRUIe0/DpkFtQhs7AOqXm1nrVSRZ4u7s/DyZJ4OIrg6WwJD0cRPJ0s
4eEkQpCXFesnsanbeCoNp34x3TRCU2BrIm1XdOnijVKs4FDjW23FsKzuGe5rDYlYEFVdJ7+spyEBAKYP9yLqWoOoanReK2V+UXUj
udJggf9b04L2u+ioJQIA5Je0TRkO87Em88f44rFuDipvd/qPArV7OXuG2JJXntfNvkYA2PZ5hs7OxZY2VZFbyyiow4I98asNVU10
ypOeZImSDICLN0qx5v1klZVTlekbyS7IYmriYHf8fqtMZ+dzdbBM2zgzxL+XmoIou77MxI2USrDdc/vcY2747nJRe4eoVu8wO7Jh
RrDaYmpp+XWYtS02/eSrXbR+cVla8NEnwo4o24+sK71Cbckbk4M0VqZeuj8BF2/ofsKtb4TqwLs9XnjcHT9c0d3zwMHGYuO700NW
PtJZ9XiPn8/FhWsl+HJdN1bnHjfAFSd/0UkooFLXQBuyaVYIvJxVxwO5xVLM3BbLeKKKCwx+Jfr+mZxPXhziMUHf92MtEqBbkI2y
WfTcunoFKmoaUF7dgIoaOSprGlBZI0dFTQOqauUtllB4AOwkAthaWcDWuvFvL2eRTqp3mYObKVV49YNkk22NYEoUCsOXuzamv+6U
q61kaCpG9nUhHo7s3y+e7ud66eQveXr5+XuG2JI1LwSoTZePz6xB9M6446WVsqmtv1dezbzP3JvHU7QaI1svPeFBdL360zy1tnOA
hMwY7g1NabBbP8vAhz/mqvy92VlbRG+cGaKzMX78Ux7SjbBNQyTkY9OsENLe/X01UjkW7Ik3SOuNCF8JWTclCOG+bZ/3h77Pxr5v
2KfD66KFijL9Ozvg4XA7oouV5IHdHMn6qUGwl6i+5DvyQzaOns3h7ZgbxvqDpkewLQZ2cyS/3tR9kOPhaEleGe+vcQUxPrMGs7fH
rvZ0Em1o7+TR8wPd8MftsnadQxkvZxFZ+pyfxp+l8TWRgGsJ+skiYNovma0uATYY0tOJ/HS9/QXs+kbYkXdmhEDd7/LTi/nY/kUG
762pwayfs6He1hgV5UK+u6z7Tg0udsKLS57zG6hpv3fTRIexCuFpy+CBY0mlbOL7Z3ImtLdBa3uILfkQW1qafeqoPtU3KLDvmyyc
OJ/L62DxjNHUN3ScB/paYiWW7Df9oBEAXh6qXYZF9Ghv/PJfCWm92tceHk6WZN4YX4zW0K/tv+RKzNsV30/VimeukpU4ZU7+kmeQ
vefdg3W7ggcAxRUydA20IUN6NqZnaypeVl0nx/JDiRoLWLw7I3h/6yIs2qquk+PQ99mrdXIylnbPDydsUxqVefd/aXoPfEVCPuaN
8SEvD22boimVKbDm/WRoc7Eb5Gml1zfl92aF4KWNd4i2qxGOtsJjayYFTNHUtuDjn/Kw5+ssnr+7WOuJgNdfCsSdt6suNu2Dbi97
icWqGSO8Nij7nbV2I7kSc++9X43t76pVxefmBnZzxIiHnYmu2ga52Asvzxjh1XfSYM2fBZU1cszZEauTlhvKuDpYpukztXjdlCCk
5tWSFC336tlaCyaumBBwUtNn1Nd/FeLdk2k8F3vh5dH9tCvItXy8P/5NrCQ5Oup7KxELoiYP9bw09UlPlXsxmzRNdJhi1wGj5L4d
P58bM3Gw+35D5cVTunU3vRpr3k/ifDEic2OMginGcCO5EvN2xVkZowm2rnUPtiXalrq3l1jg0NJIzNwam1dQVt+u/H4PR0syfbgX
mDRL/ul6Cda8n8xT9/gnZdcyut+jZ3P1XrHFy1lEds4N0/l5ne2E+HBVZ0bHpubVYsm+BI3viRMHu7erX15r+77JMshKXXMiIR+7
dBQ0/pdcCX3M+DfXK9SWrJsarHT7SHJOLZYd0Px7UyXAQ79t1hxthTiwOAIzt8bWse3pNnGwO4kZ7aN2lRFobOFy+IdsHgCo2/uo
iYu9ENvnhg2cvPGO1ucAGvugvvC4h/uEQe6Miu5cvFGKlYeT7r9fKeufqo1XXwxEekEdaU8A52BjsXHOKO+VTAJGAEjPr0PMzjjo
KpBRJsBdrNsZtlZsrAQ4uDgCM7fFErYTQs/0dyXzx/qqbEfS5Pj5XGz/orGI1otDPPpqO1Z7iQV2zQ/H5I23Pdqzhc3ZTnh2/ED3
YS887gFba81xzd9xFViyP0HlxCzXGSVwrKhpOLDvm6z9y8fr9flL6cGer7Nw5N6HDGVY+t6szwXXEiowf0+8p7F70enK2P7atx8B
AD83MU691sV9yf5EckNJOwdNeoXakkmPezAuFHHiQi6jqpZ30qp+BTBQ3TEXb5TqvRelRCyIOrA4wqiFoy7eKMXq95M07p0P8rRS
uq9OW5mFdfj4J/2kMquzZU4o6auDoBEAPv5Rf3uMbK0FE5c+53/yGRWvwS9+L8B7n6SrnSDRxBCT376uYny8uoto1ZEkclVD6qKN
lWD48Iedz0wd5sWozsLrx5Lx7aUHgfuIPm3bybDRNdAGn7/Zjbz+QTJiM9gFXAO7OZIRfZwxXElLG1U+uZiPDSfTWtyPrirS2lgJ
8P6yTlj3YQphW5zG2U54dtJg92GTh3oyrkD9X3IlFu1N0PsKlCGes64OljixsjNeP5ZMfrupfq+otUgQ8WRvp9gpT3oySvtuXU+j
PS2+ACDEywqfvtY197VjKWD7Gdu/swMZ3sdZYwZPc99eLsLrHySb9DW00T5t//dzHu+Jh5xIz5D2NfGkDCM5pxYrDiciOcc0qj6Z
o5IK5vvKTNHVhArM3RnPM5cA2UrE9ximg15ZTrZCHF/RCZ9czCf7vsnSeGER4SshI/o4Y1SUi8aZ2+be/jgVn//GrA9gUYVsUHJO
LVG3V+bCtRLG960NR1vhsf2Lwqf4sahWq2vvfZKO//3MLHjbPDtUJ/0am2z9zPAFcd6eFkwGdHXQ2fl+00PVUJGQj4mD3cmMEV6w
U1JQrLpOjnUfpuL81fanIfLYlhfWkou9EEeWReJaYiU583cRbiRXITG7hufhaEl8XMXoGWKLXmG2iIpkVvSkVqrAsoMt+wIO7uGo
k7YiIV5WOPlqF/xwpYicv1aitrhL30h7MrKPM554yIl1QLPt8wycuNByL7GNlWC4LieRrER8bJwZgrH9XcmXfxTicmy5yvffTv4S
0jPEFo/3cEQvlqueP/5bglcOJhrkyWSgp2zjat68cNxOqyI/XCnG9aRKpOTW8uwlFnk+riL3niG26BliCzYZGMsPJuLCvw9SynuH
2emkrYivmxjHV3TChWsl5Ow/xfjzTpmVqsnrXqG2ZGRfFzzZy5nR6mJz2u6j5hqjBY6EAGuOJuOrdd10+mFK6VZVrRwHv8vG/37O
48npZkajurdnwCx/CZdjy7FwT4LZBI0A0K+Tfa4um0lPGOSOCYPcN1xNqNhwM6WqxZ5XoYAHLxcRInysEejJrvBBXb0CrxxMBNsq
gj9dL0Gwl+oS6bdSq1iNgw1vFxE5tCRS475DfSmqkGHp/gTcTKli9JhNG+alNshm65/4Cr1UW1Tn6UdcySgWM+uapOfXQZfp6CIh
H+MedSOzn/JS2fP2Tlo1lh9K1GsqoD71CrVFs6qoWn0WlFbKMHdXfJsVwWG9/9/enYc3Vad7AP+G7ku6ppRKy07LqhQZqQvCyLgA
4nW5I84dZ1wGR3HcZ0aQGRUXrKgzCpfVsggDFFCgrGVTilBKwbJJaem+pE3aNGmTtFmb/O4fFS9Cm2Y5J+ekfT/Pw/PwsJz8nuQ0
57zn9y6e7TZeb/pEGaZ3NAdhTVorVFoLDCYbACA2MhAJMYFu3/u9mVHWaeCfFBec7cmau5I2MvJqUJ6ubWtPr2syw2i2ARIJ+kYG
wJVRS9dbd7Aei3fU+uT56Iwxg8IxZtDPu8BunbOtxo4GWufKfrkjeL8Lu9POuGbcmFGts6JJa0WrseOBfYw0ADfJgtw+ZxdsqEBW
rqpHfM6C9vdXqM2SL7bXMldbPxP+2RmQdaIRS7JqF7W0ts8Tej2kI1VV2WyBOx06xezbcxrMzSiTtNt6Vkx8+6goXo47ITmCszoe
hdqMOYuL3arx2pmrwp9ndB04qnXW2z1aXBdGJIWxFa+mdBkc8K2gRIc3M8oOqnXWB5z59/HRgaYXZnb9Prlj0ZYqTo/XnaS4YDaf
w/mYANCHo+fFYcF+aY9Pjs/7w739HM4/5aPMwvhTIOQrKpVG/GXJlU4DZ0ezET0liwyALNLzn9cmrRUvL70x6L3KlQwLd0WG+Xdb
N+oMO+vI8thx3LksD64YXBilJAYNzRbMWVyMzprtpHGUMt+Z2IgATs4nbVs7XlteckPQ68sEHwy3JUcpGT9cyrrr+kW853y5Hh9t
rkKJ3NBjTvSeokpp7FGB447jjfhgU6WE9ayYEQAwIVncafj5RVr87cvS3+kNNrcGNivUZkn2GTWb1sVT3wB/ycMAOC3+v3N0FPvs
+eFONc3gWpvJhn9/U4PtLt7ovfbYgCAus2p2HG9EmZdLBhY+O7TbLoGuSooLRrQ04KvOxr04IyzYL+3J3/TLe3JqgsOUsQqFEfNW
l/FyPSupM3B9SN4UlOjwyrLOG3IM6BvMuAiG+FRY1YaXl17ZqtFbn+jq3wjxveAOs9WO11eUdNuBmQ+Xq1t/ByDT26/rjsKqNry4
pLjT9ODIMP95nuz0ekNZvREvLSm+YQ6yrxP8m4Ix4O9flkqWvzKCORrySfjX2GLBv7+pgauF4MR7LlW1OV3HInbXdvPrifia78aF
a7vSeSJjXx26ChxHDwyfm1vYwlm2wjP338RefTSJq8O55HCBBumZVQ5vWjszamBYl4G1O4xmO5btlh/k7IBOmJoawzqZh8yJFx9K
fGrhpsqnXfk//WVB7OE74/C7X/dDeIjjVPC1B+qxZCd/aYDVDSaJyWJnXAfVXNt+vBEfbKzs8n0YPdC9zs/esvdUE/7pREMRXyh7
UrVY8OryEt7GbXRHb7BtadJaM7nYAeZT9mk13lpT1uV7NHZwuMdjV/j03blmzF9b1mWtpC8TPHC86q+rShLW/m2UYuQAcX+B9URm
qx3rDiqw7kC9Rx3mCP+OntdgtoAzULnSk/L9O5MoCxLlHmqTzop/rClDfjE3g6UrFEbJ9uON7LFJfW/4uxkTY5Fb2OLxa0hD/Z74
8JmhmZNv9mzQvDsaWyz4YGMljrvZxMVRKq871mTXwdkUWa78dvKNny1nx767L4pq2lh36Xr9ogPZPakxuG9CDMYN7X4n/8fKVry3
ocIrO7MFpTrcOTqK75dx26It1cg86riBU4wXUjzdtXBTJb52smmX3iDu1OH8Ii3ezCgTfHbfDyU6l7rXetvSrFqszq53+JlHS0UT
vtzg8+01WH9I0WPvb0TzzhvNduWcxcWLVr02cm5KUqjQy+k1/nNEgXUHFC4/SSfCKKxqkyibLcxX01WFftrqLREiTPv69pwGCzZU
uJ2a2pUlO2vfuntsVHpc1C/PyekTZdh/Ws1cbbpzrbtvjmLvPDmEk/ooV208osSKPXK3Z23FRwea3B2m3hmlxtLtzRQf+M5weOfJ
wUgdJmVHz2uga/v/G/+E2ECMHRSO8ckRGOZkY6FWow2Ld9Q4HWhwIStXJcrAUdvWjrfWlDmVDintpPus0JTNFryxwrVrhUZv5XNJ
Hlm+W44v94kjwyYrVyXKwLHNZMPbX5Xju3PdN/7qrGOy0NQ6K/62qrRH1TN2RlTvfEtr+7ynPilcsOzlFKOr7YyJ89ptDFm5Kqzc
K89v0lrThF4Pcc3R8xo4O1BYTApKdHhjZangT1u9QUwdiI1mOxZuruRt0Lq2rf3jNzPK0tf9fdQNf/fpn4djzuJidt7F+VjjhkrZ
0/cngMvAy1mnirRYtLUalZ00Y3DFI3fGcdry9fPt3h+/MbhfiFdO5JlpMpdmoXXmyFkN0jOrnG5axJXDBRqJztDOxHQjm3dZi7fX
lR9r0lmnCL0Wd5y41IL5a8rn6AztK135fxUK4+0A8nhallvUOivmrS7DmSvcZHlw4VSRVlKvNrObYoXpSt2Zs6V6zF9bBqXGN+sB
fyjRYa4LTdN8mXi+6X5isthNz39RLEn/0zBqmMMxu51hX74ay3bX+uwPJwG2HG3ArMnx6NPHdz7C9YcUWLyjRiKieIpXbUZxpExd
KNdj7mr+L8bnyvSSBRsq2II/DvnFn4cE9cGq10fgo81VbNdJx6nJMdKALdNui501Y6IMowSouaptNOHTr6vR3cBqZ93B4S7UxYpW
HORg7qCruJyJxxelxoL3N1YI0mjkqvWHFHj5YWHqb6+XnlmFrTkNLr0X9WozX8txid5gwydbq7DHzYdcbSbbqUqlUTT15ccuNuOf
68o5z/LgwlcHFZj/P4OEXgYA91I7xXLOGswdTdOcnYHcE4jyqtBuY/j7l6WSOTMT2fMPclsj0ltln1Zj1V65W233ibhUN5gk2441
sid+HS/0Urplttrxz7Xlvxja2xvIm8wSo9nOhOryZ7MzfLmvDhn76rwWrGflqiT9ZUHsuem//M4OCuiD954agudm9GcHz6iRd1mL
mkZTg8liX/CrlIgVE1KkuHV4BJIThSlR0BnasWpvHTZ967gOzFXD+nN38/rR5irOjuWKJp14U/9sdoaNR5RYvlsueG3+mux6yX23
xjIhy2yu1BowN6PUrWu8XCV8/46j55vxwcZKj8tmThZqBQ8cDWYbPt1ajZ0iruPfdqxBMu22WJY6TLju35VKI+ZmuNfxWK4SPnDM
u6zFu+srGhpbLL6XAuYBiSxqkNBrcGj8cClbNHsYrq+fIc7JylVh/SEFKpXebd9O+BUV7v/xvoXj5oYFczdgnmu1KhNeW16Cci+P
DhCL1X8dybiat+iKErkBCzZUCFZH+uJDiYzrpjB8MJrt2JKjxJrs+mmtRtsBLo8dFuyXlrt4Aicpc9ln1HhrddfdBfl24osJrLvu
pd52oVyPDzdVobROPCOjkhND2ba3x3r9dfUGG5buqnV5l/F63302njmag8mXhmYL0jOrkHOh+7o2Z4waGMY2zx/DxaHccuJSC9Iz
q1DXdOOsTLFJigtm37w71uvdaA1mG1buqcOGw541kNnz4S0sKc77IznUOis++7oa2ad75wQC0QeOQMdN8ofPDJ1715gooZfiE/QG
GzKPKrHlaAM1venBZt4uYx88PVToZXRq07dKLNlZK/hOgJBmpsnYB8947/NpaW3Hkqxa7DzRKPhczCm3RLOFzw6FGB9smK12bDvW
gNX763mrt5VIgLMrJjKJh7cVlnY7ZvzjQrWqxTKIk4W54f2nhrCH7ogT6uV/4cwVHVbvr+OsKzDX7hgdyf79QjLnMy87Y21nyDyq
xKq9dW43cLrWa48OYE/fn8DF0pxiabdjwyEFMvZz3819w9zRvI2Q6YpSY8HHW7gLgL0ldZiU/e9LKd2OtuGCzc6w/ftGLNst5+S7
90/TbmLeTBG32Rk2f6fEit11Iw1mW7HXXlhkfCJwvOre8THslUeSIPahn0KpVZmw8YgSWbmqXn3D3pu89HASE9N4jtpGE+avLceP
la0+dfHkS/ZH41iCFxoQZB5VYtkuOec7Z55IigtmC58dCm/fwDmyLacBX+6v80pTsAPpqaxfjGeZMp9uq+Y8hdZVv0qJYBlvjBRy
Cfj+Ygsy9tf5xPfKiKQwtvSVFMh4HHFxuECDz7fXoF7N3a5WZJj/vK1vj033RsfunAvN+NfXNahV8VM6MzghhO1ccDMfh76BwWzD
ugMKn55JPDghhC1/OQV8XqtyLjTj8+01qOawXCo0yG9E5j/GFA2M5z8myP+paVqFh03TegKfChyvmjUlns2ZmegThfveUFCqR+Z3
ShzpZXVkpMNHzw5l0yd61pGQCyv3yLFyr+9ePPkwvH8o2zR/NAL9+dmBOHJWg8U7anm7AePCsw/cxGZPvwmhQcLtPh44o8ayXXKv
vk9v/PcA9sd73d/B2XVShXfXV4jic/3kuWHsvgnebd/PWMcImeW75T53sxYfHWh676khQVyPMtl9UoV1B/krPRk9KIxteou/NM8S
uQGLtlajoIT/HeN7x8ewRc8N462JXLuN4evvG7ByT12P6BQeIw3Y8s4fBs/iupN19hk11h2od6uO0RlDEkLYDh4fElQqjfhsWw1y
C7lpmtYT+GTgCHTUkPzXHXF5v727LwYniKODljedK9Pj23MaHPpB0+sKc8mNhKwry7nQjE+2VnP69LsnmXJLNPvixWROj5lzoRlr
D9TjYoX4d2AAICSoT78ZE2WKxyfHe7UJzrGLzViaJRekFq5fTCDb9f4tbtUP/VCiw+x/FYnmsw0L9kvb+d7NeX291Gsg+4waq/b4
fjO3R+/qy156OBGe1g5uzWnAuoP1XumGPmlsFPvs+eGc1r2VyA1Yf0iBffn8jATqyr3jY9inzw/n/Lj785uwdJe8R17zpt0Wy954
bIDHfUV25qqw9kA9ahv5/xmekBzBlryUzOnDyUqlEf85rMSOE72nW6qzfDZwvNaogWHs0bv6YtptsaKsqeGCnQHnSnU4VKDB4QIN
1S6SG/wqJYJ9PHsYYnlMkbrW5eo2/OubGq88PfZ1k8ZGsc/nJMPfz/23qs1kw66TKmz+Vgm5DzRe6MqYQeHssbv74p5x0YgM4z5r
JLewBQdOq3HsYovLc+C49utx0ezzOa49NDh8VoN3vipPMJrtSp6W5ZYxg8LZqtdH8HaNbTV2nN/bjjVwms4mBvdPiGWPT4nHrcOd
62BZqTDizBUdcgu1OH1F6/VzYdxQKVv8l2SPfz6Pnm/GxiMKFJQKNxB91MAwtuzlFER7GLzb7Az789VYuVfuE41vPHVPajR7fHI8
nN01r2sy41SRFrmFLcgv0nFSd+sKrlLET1xqwcYjSpwqEm68j9j1iMDxqqCAPphySzR7ME2GSWOjhF6Ox4xmO85c0eH7H5tx5Kxm
UUtr+zyh10TELUYasOWlhxNnPXpXX95eo6zeiJV75JQa7aL+siA2e3p/zEyTOR1ANjRbcPzHFhy72Iz8Ip3E0t6zapdHDQxjE0dE
YsSAUAzvH4ohLmaPmCx2FFa34VJlKy5U6HG6WCeqOk8AmJoawz58Zii6G81itzMs3lnr8jwzb0pODGUZb4zkNOAvKNVjx/FGHCpQ
S6ztPXvQa3iI3wN3jo7KTkkKRXx0IGIjAqA32lCnMkOltUChMaO4xiCKnSxpqN8TLzyYmPn7qa4lNFU1mLA3T4VdeU2CNnW6liwi
IOe5Gf0nz5ri+girc2V6nLjUguzTalF8Lt4WGuQ34o7RkUUjB4T9fM62mWyoa+o4Z5UaC8rrjaLo3B8S1Kff7Gn9FX9yse+DvMmM
PXkq7DqpohnnTuhRgeO1IkL9X7j31pgV026LhRAt8d11vlyP/CId8ou1OCvgUzri2wbFB7NXHhmAe1K5qVcwmu048IMaO080+kx6
pFhFhvnPm3xLdPpvUmOQFBcEWWQgpKF+aGi2QK2zokJhxNkyPS6U63vlKJOUpFA2JCEESXHBP9cnMcZgMNnRZrL9/KuxxcJb3QzX
kuKC2e+n9sNDd8huSKdqaLZg10kVsnJVPnFjGiMN2DLnocRZv73b/YdTuYUtOP5jC3LON0PZTDdqYhYZ5j9v0tio9KmpMUjqGwxZ
RACiwv2h1lmh0VvR0GxBldKESqURV2oNuFQl3uuDLCIgZ0aabPJvxsdg7ODOm3Zdrm7D2VI9zpXpkV+sFd2DKNK98BC/ByaNicqe
Oj4GA+M7ztloaQCa9Vao9e1oaDajusGESoURV+QGuqdxUY8NHK+XOkzKxg2VInWYFLcmS0WR0mq22lFeb8SPla04WajFmSu6Xt3i
l3BvRFIYuyc1GmkjI13ubqkztOP7iy04claDvMta6tRLCAf6RQeyvtGBMJhsUGmtPttYY2B8MLvv1lhMGhvl8LtF3mRGcU0bimsN
KK5pww8luhCTxS78xHnS6yXKglhsZCCMZhs0eqtXui0T4ut6TeB4PVlkwKn+suCJibIg9JcFISkuGAmxgYiVdjyZ4LJja3WDCbUq
E8rqjKhVmVDdYEJ1o0k0aRykdwgL9ktLGxmZN3pQGBJlQYiJCIAEQLsdHU/idB1PjyuVRlQqjD5dR0cIIYQQQrjVawNHZ0RLA76K
Dvd/KircH6FBfggJ7IOgwD4IvvoroA8gkUBvaEer0YZWow16Y8fvdR1/RmkOhBBCCCGEEJ9HgSMhhBBCCCGEEIf4mUpNCCGEEEII
IaTHoMCREEIIIYQQQohDFDgSQgghhBBCCHGIAkdCCCGEEEIIIQ5R4EgIIYQQQgghxCEKHAkhhBBCCCGEOESBIyGEEEIIIYQQhyhw
JIQQQgghhBDiEAWOhBBCCCGEEEIcosCREEIIIYQQQohDFDgSQgghhBBCCHGIAkdCCCGEEEIIIQ5R4EgIIYQQQgghxCEKHAkhhBBC
CCGEOESBIyGEEEIIIYQQhyhwJIQQQgghhBDiEAWOhBBCCCGEEEIcosCREEIIIYQQQohDFDgSQgghhBBCCHGIAkdCCCGEEEIIIQ5R
4EgIIYQQQgghxCEKHAkhhBBCCCGEOPR/YwH+0HRGrnMAAAAASUVORK5CYII=

NISKALA_B64_EOF

cat > .gitignore << 'NISKALA_FILE_EOF'
node_modules/
.next/
.env.local
.env
NISKALA_FILE_EOF

if [ ! -f .env.local ]; then
cat > .env.local << 'NISKALA_FILE_EOF'
# Isi ini sebelum npm run dev:
POSTGRES_URL=
AUTH_SECRET=ganti-dengan-string-random-panjang
# Opsional, untuk tafsir mimpi penuh:
ANTHROPIC_API_KEY=
# Opsional, untuk forgot password lewat email (dari resend.com):
RESEND_API_KEY=
RESEND_FROM_EMAIL=Niskala <onboarding@resend.dev>
NISKALA_FILE_EOF
fi

echo ""
echo "✔ Semua file dibuat/diupdate (termasuk logo)."
echo "  (.env.local tidak ditimpa kalau sudah ada isinya)"
echo "Selanjutnya:"
echo "  1. npm install"
echo "  2. npm run dev"
echo "  3. Buka /api/setup sekali untuk bikin tabel (kalau belum)"
