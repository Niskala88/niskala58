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
