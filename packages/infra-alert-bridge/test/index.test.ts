import { describe, expect, it } from "vitest";
import worker from "../src/index";
import type { Env } from "../src/types";

describe("healthz", () => {
  it("returns version metadata", async () => {
    const response = await worker.fetch(new Request("https://bridge.example/healthz"), {
      VERSION: "test",
    } as Env);

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ ok: true, version: "test" });
  });
});
