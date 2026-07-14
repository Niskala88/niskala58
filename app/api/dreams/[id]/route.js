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
