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
