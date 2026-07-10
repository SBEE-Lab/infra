import { describe, expect, it } from "vitest";
import { canonicalizeAlertmanagerPayload } from "../src/alertmanager";
import type { AlertmanagerPayload, Env } from "../src/types";

const env = {
  SLACK_INFRA_ALERTS_CHANNEL_ID: "C-alerts",
  SLACK_INFRA_AUDIT_CHANNEL_ID: "C-audit",
} as Env;

describe("Alertmanager payload canonicalization", () => {
  it("preserves Alertmanager and source links", () => {
    const payload: AlertmanagerPayload = {
      receiver: "infra-alerts",
      status: "firing",
      externalURL: "https://logging.sjanglab.org/alertmanager",
      alerts: [
        {
          status: "firing",
          generatorURL: "https://prometheus.sjanglab.org/graph?g0.expr=up == 0",
          labels: {
            alertname: "PrometheusTargetDown",
            severity: "critical",
            job: "node",
          },
          annotations: {
            summary: "Prometheus target down",
            dashboard_url: "https://grafana.sjanglab.org/d/node/rho",
            runbook_url: "https://runbooks.sjanglab.org/prometheus-target-down",
          },
          startsAt: "2026-07-10T05:25:00Z",
          fingerprint: "target-down-node",
        },
      ],
    };

    expect(canonicalizeAlertmanagerPayload(payload, env)[0]).toMatchObject({
      fingerprint: "target-down-node",
      externalURL: "https://logging.sjanglab.org/alertmanager",
      sourceURL: "https://prometheus.sjanglab.org/graph?g0.expr=up == 0",
      annotations: {
        dashboard_url: "https://grafana.sjanglab.org/d/node/rho",
        runbook_url: "https://runbooks.sjanglab.org/prometheus-target-down",
      },
      channelId: "C-alerts",
    });
  });
});
