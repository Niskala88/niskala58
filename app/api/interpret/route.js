// POST /api/interpret — multi-lens dream interpretation via Claude.
// Requires ANTHROPIC_API_KEY in env. Returns 503 if not configured,
// and the client falls back to the offline lexicon.

export async function POST(request) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return Response.json({ error: "not_configured" }, { status: 503 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }

  const { text, mood, lang, profile, pastDreams } = body || {};
  if (!text || typeof text !== "string" || text.length > 4000) {
    return Response.json({ error: "bad_request" }, { status: 400 });
  }
  const overallLang = lang === "en" ? "English" : "Indonesian";

  const profileLine = profile && (profile.pancasuda || profile.sign)
    ? `\nDreamer's own profile (weave this in only in the "overall" field, only if genuinely relevant — don't force it): pancasuda temperament "${profile.pancasuda || "unknown"}" (a Javanese weton-based baseline character trait), zodiac sign "${profile.sign || "unknown"}", core bazi element "${profile.dayMasterElement || "unknown"}".`
    : "";

  const historyBlock = Array.isArray(pastDreams) && pastDreams.length > 0
    ? `\nDreamer's recent past dreams, most recent first, for pattern-spotting only (don't interpret these individually, just note if today's dream echoes, contrasts, or continues something from them):\n${pastDreams.map((d, i) => `${i + 1}. """${String(d).slice(0, 300)}"""`).join("\n")}`
    : "";

  const prompt = `You are a genuinely skilled dream analyst writing for a dream journal app — think the depth of a real analytic session, not a fortune-cookie summary. The dreamer is Indonesian and may write in mixed Indonesian/English.

Dream to interpret today: """${text}"""
${mood ? `Mood on waking: ${mood}` : ""}
${profileLine}
${historyBlock}

Interpret this dream HOLISTICALLY and with real depth — as a single unfolding narrative, not a checklist of symbols translated one by one. For each of the three lenses below:
- Track the dream's SEQUENCE (what happened first, what followed, what shifted) and treat the order as meaningful, not incidental.
- Notice specific, odd, or emotionally-charged DETAILS in the dream's own wording — an unusual color, a repeated action, something that felt "off" — and build the interpretation around those specifics rather than generic symbol-dictionary meanings.
- Name the TENSION or QUESTION the dream seems to be sitting with, not just a single tidy meaning.
- If the dreamer's recent dreams are provided above, explicitly note any echo, escalation, or contrast with this dream where genuinely relevant — this is one of the most valuable things you can offer.
- Write 5-7 sentences per lens — enough room to actually reason through the dream, not just assert a conclusion. Write ALL THREE lenses (jung, primbon, islamic) in ${overallLang} — the dreamer selected ${overallLang} as their app language, so every field in your response must be in ${overallLang}, with no exceptions, even though these are culturally distinct traditions.

Then write two more fields:
- "overall": a ${overallLang} synthesis (5-7 sentences) that pulls the three lenses together — where they agree, where they genuinely diverge (don't manufacture disagreement if there isn't any), what the dream's central tension actually seems to be, and the most useful thing for the dreamer to sit with. If a dreamer profile was given and it's genuinely relevant, weave in one sentence connecting the dream to that pattern — otherwise skip it. Write this in your own voice, warm but direct, second person ("you"), not clinical.
- "questions": an array of exactly 2 short, specific, non-generic reflective questions (in ${overallLang}) that the dream itself raises for this dreamer — questions they could actually sit with, not "what does this mean to you" filler.

Respond with ONLY a JSON object, no markdown fences, in this exact shape:
{"symbols": ["up to 4 key symbols as short lowercase words"], "jung": "...", "primbon": "...", "islamic": "...", "overall": "...", "questions": ["...", "..."]}

For the islamic lens, draw on the classical Ibn Sirin tradition and keep a respectful, non-fatalistic tone (readings are possibilities, wallahu a'lam). Never predict death, illness, or disaster literally.`;

  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 1800,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!res.ok) {
      return Response.json({ error: "upstream" }, { status: 502 });
    }

    const data = await res.json();
    const raw = (data.content || [])
      .map((c) => (c.type === "text" ? c.text : ""))
      .join("");
    const clean = raw.replace(/```json|```/g, "").trim();
    const parsed = JSON.parse(clean);

    return Response.json({
      symbols: Array.isArray(parsed.symbols) ? parsed.symbols.slice(0, 4) : [],
      jung: String(parsed.jung || ""),
      primbon: String(parsed.primbon || ""),
      islamic: String(parsed.islamic || ""),
      overall: String(parsed.overall || ""),
      questions: Array.isArray(parsed.questions) ? parsed.questions.slice(0, 2).map(String) : [],
    });
  } catch {
    return Response.json({ error: "parse_failed" }, { status: 502 });
  }
}
