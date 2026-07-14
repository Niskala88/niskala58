import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";

const COOKIE = "niskala_session";
const secret = () =>
  new TextEncoder().encode(process.env.AUTH_SECRET || "dev-secret-change-me");

export async function createSession(userId) {
  const token = await new SignJWT({ sub: String(userId) })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(secret());
  cookies().set(COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    maxAge: 60 * 60 * 24 * 30,
    path: "/",
  });
}

export async function getUserId() {
  const token = cookies().get(COOKIE)?.value;
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, secret());
    return payload.sub ? Number(payload.sub) : null;
  } catch {
    return null;
  }
}

export function clearSession() {
  cookies().delete(COOKIE);
}
