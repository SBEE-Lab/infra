import { HttpError } from "./alertmanager";
import { postBlocks } from "./slack";
import type { Env } from "./types";

// Slack caps a section at 3000 characters and a message at 50 blocks.
const MAX_SECTION_LENGTH = 3000;
const MAX_SECTIONS = 40;

interface DigestPayload {
  title?: unknown;
  sections?: unknown;
}

export async function handleDigest(request: Request, env: Env): Promise<Response> {
  // rho already holds this token for Alertmanager and is where the digest runs.
  if (request.headers.get("Authorization") !== `Bearer ${env.ALERTMANAGER_WEBHOOK_TOKEN}`) {
    throw new HttpError(401, "unauthorized");
  }

  const payload = (await request.json()) as DigestPayload;
  const title = typeof payload.title === "string" ? payload.title.trim() : "";
  const sections = Array.isArray(payload.sections) ? payload.sections : [];
  const valid =
    title.length > 0 &&
    title.length <= 150 &&
    sections.length > 0 &&
    sections.length <= MAX_SECTIONS &&
    sections.every((section) => typeof section === "string" && section.length > 0 && section.length <= MAX_SECTION_LENGTH);
  if (!valid) {
    throw new HttpError(400, "invalid_digest");
  }

  const blocks = [
    { type: "header", text: { type: "plain_text", text: title } },
    ...(sections as string[]).map((text) => ({ type: "section", text: { type: "mrkdwn", text } })),
  ];
  const ts = await postBlocks(env, env.SLACK_INFRA_AUDIT_CHANNEL_ID, title, blocks);
  return new Response(JSON.stringify({ ok: true, ts }), {
    headers: { "Content-Type": "application/json" },
  });
}
