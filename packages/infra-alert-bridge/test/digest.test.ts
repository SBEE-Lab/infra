import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import type { Env } from "../src/types";

const env = {
  SLACK_BOT_TOKEN: "xoxb-test",
  SLACK_INFRA_ALERTS_CHANNEL_ID: "C_ALERTS",
  SLACK_INFRA_AUDIT_CHANNEL_ID: "C_AUDIT",
  ALERTMANAGER_WEBHOOK_TOKEN: "am-token",
} as Env;

function digestRequest(body: unknown, token = "am-token"): Request {
  return new Request("https://bridge.example/digest", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("digest", () => {
  it("posts the digest to the audit channel", async () => {
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ ok: true, ts: "1.2" })));
    vi.stubGlobal("fetch", fetchMock);

    const response = await worker.fetch(
      digestRequest({ title: "Weekly audit 10/16-10/23", sections: ["*Indicators*\nall 0", "*Pressure*\nbans 4"] }),
      env,
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ ok: true, ts: "1.2" });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("https://slack.com/api/chat.postMessage");
    const body = JSON.parse(init.body as string);
    expect(body.channel).toBe("C_AUDIT");
    expect(body.text).toBe("Weekly audit 10/16-10/23");
    expect(body.blocks.map((block: { type: string }) => block.type)).toEqual(["header", "section", "section"]);
    expect(body.blocks[1].text.text).toBe("*Indicators*\nall 0");
  });

  it("rejects a wrong token without calling Slack", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const response = await worker.fetch(digestRequest({ title: "x", sections: ["y"] }, "wrong"), env);

    expect(response.status).toBe(401);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects an empty or oversized digest", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const empty = await worker.fetch(digestRequest({ title: "x", sections: [] }), env);
    const huge = await worker.fetch(digestRequest({ title: "x", sections: ["a".repeat(3001)] }), env);
    const tooMany = await worker.fetch(digestRequest({ title: "x", sections: Array(41).fill("s") }), env);

    expect([empty.status, huge.status, tooMany.status]).toEqual([400, 400, 400]);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
