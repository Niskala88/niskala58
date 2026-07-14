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

    // In proxied dev environments (Codespaces, ngrok, etc.) the
    // server's own request.url is often "localhost" even though the
    // browser is on a public forwarded URL. Prefer the forwarded
    // headers the proxy sets, and only fall back to request.url when
    // they're absent (e.g. plain localhost with no proxy, or once
    // deployed behind Vercel which sets these correctly too).
    const forwardedHost = request.headers.get("x-forwarded-host") || request.headers.get("host");
    const forwardedProto = request.headers.get("x-forwarded-proto") || "https";
    const origin = forwardedHost ? `${forwardedProto}://${forwardedHost}` : new URL(request.url).origin;
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
      console.log("forgot-password: email sent, id:", data?.id, "| link used:", link);
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
