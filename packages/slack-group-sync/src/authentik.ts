/**
 * Reads and changes the authentik side through its API, as a service account
 * whose role allows only membership changes in the synced groups and account
 * activation.
 */

import { z } from "zod";

import { type Action, type AuthentikState, DEACTIVATED_MARK } from "./plan.ts";

const page = <T extends z.ZodType>(item: T) =>
  z.object({
    pagination: z.object({ next: z.number() }),
    results: z.array(item),
  });

const userRow = z.looseObject({
  pk: z.number(),
  name: z.string(),
  username: z.string(),
  is_active: z.boolean(),
  attributes: z.record(z.string(), z.unknown()),
  groups_obj: z.array(z.looseObject({ name: z.string() })),
});

const connectionRow = z.looseObject({ user: z.number(), identifier: z.string() });
const groupRow = z.looseObject({ pk: z.string(), name: z.string() });

export class Authentik {
  private readonly url: string;
  private readonly token: string;
  private groupPks = new Map<string, string>();

  constructor(url: string, token: string) {
    this.url = url;
    this.token = token;
  }

  private async request(path: string, init: RequestInit = {}): Promise<unknown> {
    const response = await fetch(`${this.url}/api/v3/${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${this.token}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) {
      throw new Error(`authentik ${init.method ?? "GET"} ${path}: HTTP ${response.status}`);
    }
    return response.status === 204 ? undefined : response.json();
  }

  private async all<T extends z.ZodType>(path: string, item: T): Promise<z.infer<T>[]> {
    const rows: z.infer<T>[] = [];
    for (let number = 1; number > 0; ) {
      const separator = path.includes("?") ? "&" : "?";
      const body = page(item).parse(
        await this.request(`${path}${separator}page_size=100&page=${number}`),
      );
      rows.push(...body.results);
      number = body.pagination.next;
    }
    return rows;
  }

  async read(sourceSlug: string, groupNames: readonly string[]): Promise<AuthentikState> {
    const [users, connections, groups] = await Promise.all([
      this.all("core/users/?include_groups=true", userRow),
      this.all(`sources/user_connections/oauth/?source__slug=${encodeURIComponent(sourceSlug)}`, connectionRow),
      this.all("core/groups/?include_users=false", groupRow),
    ]);
    this.groupPks = new Map(groups.map((group) => [group.name, group.pk]));
    const missing = groupNames.filter((name) => !this.groupPks.has(name));
    if (missing.length > 0) {
      throw new Error(`authentik group(s) missing: ${missing.join(", ")}`);
    }
    const slackIds = new Map(connections.map((row) => [row.user, row.identifier]));
    return {
      users: users.map((user) => ({
        pk: user.pk,
        name: user.name || user.username,
        slackId: slackIds.get(user.pk),
        groups: new Set(user.groups_obj.map((group) => group.name)),
        active: user.is_active,
        attributes: user.attributes,
      })),
    };
  }

  async apply(action: Action): Promise<void> {
    const { user } = action;
    if (action.kind === "add" || action.kind === "remove") {
      const pk = this.groupPks.get(action.group ?? "");
      if (!pk) {
        throw new Error(`unknown group ${action.group ?? ""}`);
      }
      const verb = action.kind === "add" ? "add_user" : "remove_user";
      await this.request(`core/groups/${pk}/${verb}/`, {
        method: "POST",
        body: JSON.stringify({ pk: user.pk }),
      });
      return;
    }
    // PATCH replaces the attributes object; authentik keeps its own user
    // settings there, so send the current one with only the mark changed.
    const attributes = { ...user.attributes };
    if (action.kind === "deactivate") {
      attributes[DEACTIVATED_MARK] = true;
    } else {
      delete attributes[DEACTIVATED_MARK];
    }
    await this.request(`core/users/${user.pk}/`, {
      method: "PATCH",
      body: JSON.stringify({ is_active: action.kind === "reactivate", attributes }),
    });
  }
}
