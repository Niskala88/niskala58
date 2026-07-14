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
