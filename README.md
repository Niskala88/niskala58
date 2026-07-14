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
