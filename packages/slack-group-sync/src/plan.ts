/**
 * Decides which authentik group memberships and account states follow from
 * Slack's user groups. Pure: it reads two snapshots and returns actions, so
 * every rule about who gains or loses access is testable without a network.
 */

/** User attribute set on accounts this program deactivated, and only those. */
export const DEACTIVATED_MARK = "slack-group-sync/deactivated";

export interface Mapping {
  /** Slack user group handle to the authentik group it grants. */
  readonly groups: Readonly<Record<string, string>>;
  /** Group an account sits in until a mapped group is granted. */
  readonly pending: string;
  /** Accounts in these groups are never deactivated. */
  readonly protected: readonly string[];
}

export interface SlackGroup {
  readonly handle: string;
  readonly members: readonly string[];
  /** Slack user who last changed the group. */
  readonly updatedBy: string;
}

export interface SlackUser {
  readonly deleted: boolean;
  /** Workspace admin or owner. */
  readonly admin: boolean;
}

export interface SlackState {
  readonly groups: readonly SlackGroup[];
  readonly users: ReadonlyMap<string, SlackUser>;
}

export interface AuthentikUser {
  readonly pk: number;
  readonly name: string;
  /** Identifier of the user's Slack source connection, if any. */
  readonly slackId: string | undefined;
  /** Names of the groups the user belongs to. */
  readonly groups: ReadonlySet<string>;
  readonly active: boolean;
  readonly attributes: Readonly<Record<string, unknown>>;
}

export interface AuthentikState {
  readonly users: readonly AuthentikUser[];
}

export interface Action {
  readonly kind: "add" | "remove" | "deactivate" | "reactivate";
  readonly user: AuthentikUser;
  readonly group?: string;
}

export interface Plan {
  readonly actions: readonly Action[];
  readonly warnings: readonly string[];
  /** Set when nothing may be applied; says why. */
  readonly halt?: string;
}

export interface PlanOptions {
  /** Apply even a removal larger than the safety limit. */
  readonly force?: boolean;
}

/** Losses above this share of synced accounts look like a mistake, not policy. */
const maxLossShare = 0.3;
const minLossLimit = 3;

export function plan(
  slack: SlackState,
  authentik: AuthentikState,
  mapping: Mapping,
  options: PlanOptions = {},
): Plan {
  const warnings: string[] = [];
  const byHandle = new Map(slack.groups.map((group) => [group.handle, group]));

  // An absent group would read as "nobody", so its members would all lose
  // access; refuse rather than guess.
  const missing = Object.keys(mapping.groups).filter((h) => !byHandle.has(h));
  if (missing.length > 0) {
    return {
      actions: [],
      warnings,
      halt: `Slack user group(s) missing: ${missing.join(", ")}`,
    };
  }

  // Only workspace admins may grant access through a group. A group last
  // changed by anyone else keeps its current authentik members until an admin
  // touches it again.
  const trusted = new Set<string>();
  for (const handle of Object.keys(mapping.groups)) {
    const group = byHandle.get(handle);
    if (group && slack.users.get(group.updatedBy)?.admin) {
      trusted.add(handle);
    } else {
      warnings.push(
        `Slack user group @${handle} was last changed by ${group?.updatedBy ?? "unknown"}, not an admin; its members are left as they are`,
      );
    }
  }

  const adds: Action[] = [];
  const removes: Action[] = [];
  const states: Action[] = [];
  const managed = Object.values(mapping.groups);

  for (const user of authentik.users) {
    if (user.slackId === undefined) {
      continue;
    }
    const slackId = user.slackId;
    const desired = new Set<string>();
    for (const [handle, group] of Object.entries(mapping.groups)) {
      const keep = trusted.has(handle)
        ? (byHandle.get(handle)?.members.includes(slackId) ?? false)
        : user.groups.has(group);
      if (keep) {
        desired.add(group);
      }
    }
    for (const group of managed) {
      if (desired.has(group) && !user.groups.has(group)) {
        adds.push({ kind: "add", user, group });
      }
      if (!desired.has(group) && user.groups.has(group)) {
        removes.push({ kind: "remove", user, group });
      }
    }
    if (desired.size > 0 && user.groups.has(mapping.pending)) {
      removes.push({ kind: "remove", user, group: mapping.pending });
    }

    const slackUser = slack.users.get(slackId);
    if (slackUser === undefined) {
      warnings.push(`${user.name}: Slack user ${slackId} is not in the workspace`);
      continue;
    }
    const isProtected = mapping.protected.some((group) => user.groups.has(group));
    if (slackUser.deleted && user.active && !isProtected) {
      states.push({ kind: "deactivate", user });
    }
    if (!slackUser.deleted && !user.active && user.attributes[DEACTIVATED_MARK] === true) {
      states.push({ kind: "reactivate", user });
    }
  }

  const synced = authentik.users.filter((user) => user.slackId !== undefined).length;
  const limit = Math.max(minLossLimit, Math.ceil(synced * maxLossShare));
  const losses =
    removes.filter((action) => action.group !== mapping.pending).length +
    states.filter((action) => action.kind === "deactivate").length;
  if (losses > limit && !options.force) {
    return {
      actions: [],
      warnings,
      halt: `would remove ${losses} memberships or accounts at once, more than the limit of ${limit}; rerun with --force if intended`,
    };
  }

  // Grants first, so a role change never leaves a gap without access.
  return { actions: [...adds, ...removes, ...states], warnings };
}
