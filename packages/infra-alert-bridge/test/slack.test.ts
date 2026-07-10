import { describe, expect, it } from "vitest";
import { messagePayload } from "../src/slack";
import type { CanonicalAlert } from "../src/types";

const alert: CanonicalAlert = {
  fingerprint: "realurl-smoke-20260710T053210Z",
  source: "alertmanager",
  receiver: "infra-alerts",
  status: "firing",
  severity: "critical",
  alertname: "DiskSpaceLow",
  summary: "Disk space is low",
  description: "rho /var is above 90% usage",
  labels: {
    alertname: "DiskSpaceLow",
    severity: "critical",
    service: "node-exporter",
    host: "rho",
  },
  annotations: {
    summary: "Disk space is low",
    description: "rho /var is above 90% usage",
    runbook_url: "https://github.com/SBEE-Lab/infra/blob/main/docs/admin/monitoring.md#prometheus-rho",
    dashboard_url: "https://logging.sjanglab.org/d/sjanglab-hosts/sjanglab-hosts?orgId=1",
  },
  startsAt: "2026-07-10T05:25:00Z",
  endsAt: "",
  externalURL: "https://logging.sjanglab.org/alertmanager",
  sourceURL: "https://prometheus.sjanglab.org/graph?g0.expr=node_filesystem_avail_bytes",
  channelId: "C0BF0DCSG5U",
};

describe("Slack alert payload", () => {
  it("adds actionable links and keeps low-priority metadata in context", () => {
    const payload = messagePayload(alert, 1783661532, 2);
    const actions = payload.blocks.find((block) => isBlock(block, "actions"));
    expect(actions).toBeDefined();

    const elements = (actions as { elements: Array<{ text: { text: string }; url: string }> }).elements;
    expect(elements.map((element) => [element.text.text, element.url])).toEqual([
      [
        "Alertmanager",
        "https://logging.sjanglab.org/alertmanager/#/alerts?filter=%7Balertname%3D%22DiskSpaceLow%22%2Cseverity%3D%22critical%22%2Chost%3D%22rho%22%2Cservice%3D%22node-exporter%22%7D",
      ],
      ["Source", "https://prometheus.sjanglab.org/graph?g0.expr=node_filesystem_avail_bytes"],
      ["Dashboard", "https://logging.sjanglab.org/d/sjanglab-hosts/sjanglab-hosts?orgId=1"],
      [
        "Runbook",
        "https://github.com/SBEE-Lab/infra/blob/main/docs/admin/monitoring.md#prometheus-rho",
      ],
    ]);

    const fieldTexts = payload.blocks
      .filter((block) => isBlock(block, "section"))
      .flatMap((block) => ("fields" in block ? (block.fields as Array<{ text: string }>) : []))
      .map((field) => field.text);
    expect(fieldTexts).not.toContain("*Fingerprint*\nrealurl-smok");
    expect(fieldTexts).not.toContain("*Repeats*\n2");

    const context = payload.blocks.find((block) => isBlock(block, "context"));
    expect(context).toMatchObject({
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: "source=alertmanager · receiver=infra-alerts · repeats=2 · fingerprint=realurl-smok",
        },
      ],
    });
  });
});

function isBlock(block: unknown, type: string): block is { type: string; fields?: unknown; elements?: unknown } {
  return typeof block === "object" && block !== null && "type" in block && block.type === type;
}
