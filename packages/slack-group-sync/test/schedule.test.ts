/**
 * The safety-net reconciles follow Seoul time whatever the host's zone is.
 */

import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { untilNext } from "../src/schedule.ts";

const times = ["09:00", "13:00", "18:00"];
const minutes = (ms: number) => ms / 60_000;

describe("untilNext", () => {
  it("waits for the next time later today", () => {
    // 10:30 in Seoul.
    const now = new Date("2026-11-06T01:30:00Z");
    assert.equal(minutes(untilNext(times, "Asia/Seoul", now)), 150);
  });

  it("wraps to tomorrow morning after the last time", () => {
    // 20:00 in Seoul.
    const now = new Date("2026-11-06T11:00:00Z");
    assert.equal(minutes(untilNext(times, "Asia/Seoul", now)), 13 * 60);
  });

  it("does not fire twice at the exact time", () => {
    // 13:00:00 in Seoul.
    const now = new Date("2026-11-06T04:00:00Z");
    assert.equal(minutes(untilNext(times, "Asia/Seoul", now)), 5 * 60);
  });
});
