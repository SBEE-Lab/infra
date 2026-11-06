/**
 * Settings from the environment, secrets from systemd credentials. Tokens are
 * read from $CREDENTIALS_DIRECTORY so they never sit in the environment or
 * the Nix store; for a run by hand the same names work as variables.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";

import { z } from "zod";

import type { Mapping } from "./plan.ts";

export interface Config {
  readonly slackBotToken: string;
  readonly slackAppToken: string;
  readonly authentikUrl: string;
  readonly authentikToken: string;
  readonly sourceSlug: string;
  readonly mapping: Mapping;
  readonly connections: number;
  readonly times: readonly string[];
  readonly timezone: string;
  readonly healthPort: number;
  /** Health turns bad when no reconcile succeeded for this long. */
  readonly maxQuietMs: number;
  readonly debounceMs: number;
}

export class ConfigError extends Error {}

const env = z.object({
  AUTHENTIK_URL: z.url().default("https://auth.sjanglab.org"),
  SOURCE_SLUG: z.string().min(1).default("slack"),
  // researchers=sjanglab-researchers,students=sjanglab-students
  SYNC_GROUPS: z.string().regex(/^[a-z0-9_-]+=[a-z0-9_-]+(,[a-z0-9_-]+=[a-z0-9_-]+)*$/),
  PENDING_GROUP: z.string().min(1),
  PROTECTED_GROUPS: z.string().min(1),
  SOCKET_CONNECTIONS: z.coerce.number().int().min(1).max(10).default(2),
  RECONCILE_TIMES: z
    .string()
    .regex(/^\d{2}:\d{2}(,\d{2}:\d{2})*$/)
    .default("09:00,13:00,18:00"),
  TIMEZONE: z.string().min(1).default("Asia/Seoul"),
  HEALTH_PORT: z.coerce.number().int().min(1).max(65535).default(9465),
  MAX_QUIET_HOURS: z.coerce.number().positive().default(16),
});

const secrets = {
  slackBotToken: { name: "slack-bot-token", env: "SLACK_BOT_TOKEN", prefix: "xoxb-" },
  slackAppToken: { name: "slack-app-token", env: "SLACK_APP_TOKEN", prefix: "xapp-" },
  authentikToken: { name: "authentik-token", env: "AUTHENTIK_TOKEN", prefix: "" },
} as const;

function secret(spec: (typeof secrets)[keyof typeof secrets], source: NodeJS.ProcessEnv): string {
  const dir = source.CREDENTIALS_DIRECTORY;
  let value = source[spec.env];
  if (dir) {
    try {
      value = readFileSync(join(dir, spec.name), "utf8");
    } catch {
      // Fall back to the variable.
    }
  }
  value = value?.trim();
  if (!value) {
    throw new ConfigError(`${spec.name} is missing`);
  }
  // Name the secret, never its value.
  if (!value.startsWith(spec.prefix)) {
    throw new ConfigError(`${spec.name} does not start with ${spec.prefix}`);
  }
  return value;
}

export function loadConfig(source: NodeJS.ProcessEnv = process.env): Config {
  const parsed = env.safeParse(source);
  if (!parsed.success) {
    const names = parsed.error.issues.map((issue) => issue.path.join(".")).join(", ");
    throw new ConfigError(`invalid settings: ${names}`);
  }
  const e = parsed.data;
  return {
    slackBotToken: secret(secrets.slackBotToken, source),
    slackAppToken: secret(secrets.slackAppToken, source),
    authentikToken: secret(secrets.authentikToken, source),
    authentikUrl: e.AUTHENTIK_URL.replace(/\/$/, ""),
    sourceSlug: e.SOURCE_SLUG,
    mapping: {
      groups: Object.fromEntries(e.SYNC_GROUPS.split(",").map((pair) => pair.split("=") as [string, string])),
      pending: e.PENDING_GROUP,
      protected: e.PROTECTED_GROUPS.split(","),
    },
    connections: e.SOCKET_CONNECTIONS,
    times: e.RECONCILE_TIMES.split(","),
    timezone: e.TIMEZONE,
    healthPort: e.HEALTH_PORT,
    maxQuietMs: e.MAX_QUIET_HOURS * 3_600_000,
    debounceMs: 5_000,
  };
}
