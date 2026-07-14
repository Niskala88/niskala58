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
