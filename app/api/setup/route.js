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
