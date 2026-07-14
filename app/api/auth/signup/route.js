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
