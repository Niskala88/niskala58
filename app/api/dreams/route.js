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
