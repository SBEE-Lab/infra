/**
 * The plan turns Slack's user groups into authentik group changes. It is the
 * only place that decides who gains or loses access, so these cases pin what
 * it may and may not touch.
 */

import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  type AuthentikState,
  DEACTIVATED_MARK,
  type Mapping,
  plan,
  type SlackState,
} from "../src/plan.ts";

const mapping: Mapping = {
  groups: {
    researchers: "sjanglab-researchers",
    students: "sjanglab-students",
    staff: "sjanglab-staff",
  },
  pending: "sjanglab-pending",
  protected: ["sjanglab-admins"],
};

const ADMIN = "UADMIN";

function slack(
  members: Partial<Record<"researchers" | "students" | "staff", string[]>>,
  users: Record<string, { deleted?: boolean; admin?: boolean }> = {},
  updatedBy: Partial<Record<string, string>> = {},
): SlackState {
  const known = new Set(Object.values(members).flat());
  known.add(ADMIN);
  return {
    groups: Object.entries(members).map(([handle, ids]) => ({
      handle,
      members: ids,
      updatedBy: updatedBy[handle] ?? ADMIN,
    })),
    users: new Map(
      [...known, ...Object.keys(users)].map((id) => [
        id,
        {
          deleted: users[id]?.deleted ?? false,
          admin: id === ADMIN || (users[id]?.admin ?? false),
        },
      ]),
    ),
  };
}

interface Person {
  pk: number;
  name: string;
  slack?: string;
  groups?: string[];
  active?: boolean;
  attributes?: Record<string, unknown>;
}

function authentik(...people: Person[]): AuthentikState {
  return {
    users: people.map((p) => ({
      pk: p.pk,
      name: p.name,
      slackId: p.slack,
      groups: new Set(p.groups ?? []),
      active: p.active ?? true,
      attributes: p.attributes ?? {},
    })),
  };
}

const all = ["researchers", "students", "staff"] as const;
const full = (extra: Partial<Record<(typeof all)[number], string[]>>) => ({
  researchers: [],
  students: [],
  staff: [],
  ...extra,
});

describe("plan", () => {
  it("changes nothing when both sides already agree", () => {
    const result = plan(
      slack(full({ researchers: ["U1"], students: ["U2"] })),
      authentik(
        { pk: 1, name: "a", slack: "U1", groups: ["sjanglab-researchers"] },
        { pk: 2, name: "b", slack: "U2", groups: ["sjanglab-students"] },
      ),
      mapping,
    );
    assert.deepEqual(result.actions, []);
    assert.equal(result.halt, undefined);
  });

  it("adds the new group before removing the old one on a role change", () => {
    const result = plan(
      slack(full({ researchers: ["U1"] })),
      authentik({ pk: 1, name: "a", slack: "U1", groups: ["sjanglab-students"] }),
      mapping,
    );
    assert.deepEqual(
      result.actions.map((a) => `${a.kind} ${a.group ?? ""}`),
      ["add sjanglab-researchers", "remove sjanglab-students"],
    );
  });

  it("takes an approved account out of pending", () => {
    const result = plan(
      slack(full({ staff: ["U1"] })),
      authentik({ pk: 1, name: "a", slack: "U1", groups: ["sjanglab-pending"] }),
      mapping,
    );
    assert.deepEqual(
      result.actions.map((a) => `${a.kind} ${a.group ?? ""}`),
      ["add sjanglab-staff", "remove sjanglab-pending"],
    );
  });

  it("leaves groups it does not manage and accounts without Slack alone", () => {
    const result = plan(
      slack(full({})),
      authentik(
        { pk: 1, name: "admin", slack: "U1", groups: ["sjanglab-admins"] },
        { pk: 2, name: "akadmin", groups: ["sjanglab-researchers"] },
      ),
      mapping,
    );
    assert.deepEqual(result.actions, []);
  });

  it("deactivates an account whose Slack user was deactivated, and marks it", () => {
    const result = plan(
      slack(full({}), { U1: { deleted: true } }),
      authentik({ pk: 1, name: "a", slack: "U1" }),
      mapping,
    );
    assert.deepEqual(
      result.actions.map((a) => a.kind),
      ["deactivate"],
    );
  });

  it("never deactivates a protected account", () => {
    const result = plan(
      slack(full({}), { U1: { deleted: true } }),
      authentik({ pk: 1, name: "a", slack: "U1", groups: ["sjanglab-admins"] }),
      mapping,
    );
    assert.deepEqual(result.actions, []);
  });

  it("reactivates only an account it deactivated itself", () => {
    const result = plan(
      slack(full({}), { U1: {}, U2: {} }),
      authentik(
        {
          pk: 1,
          name: "synced",
          slack: "U1",
          active: false,
          attributes: { [DEACTIVATED_MARK]: true },
        },
        { pk: 2, name: "by hand", slack: "U2", active: false },
      ),
      mapping,
    );
    assert.deepEqual(
      result.actions.map((a) => `${a.kind} ${a.user.name}`),
      ["reactivate synced"],
    );
  });

  it("halts when a mapped Slack group is missing", () => {
    const result = plan(
      slack({ researchers: ["U1"], students: [] }),
      authentik({ pk: 1, name: "a", slack: "U1", groups: ["sjanglab-researchers"] }),
      mapping,
    );
    assert.match(result.halt ?? "", /staff/);
    assert.deepEqual(result.actions, []);
  });

  it("halts on a mass removal unless forced", () => {
    const people = Array.from({ length: 10 }, (_, i) => ({
      pk: i,
      name: `p${i}`,
      slack: `U${i}`,
      groups: ["sjanglab-students"],
    }));
    const emptied = slack(full({}));
    const halted = plan(emptied, authentik(...people), mapping);
    assert.match(halted.halt ?? "", /remove/);
    assert.deepEqual(halted.actions, []);

    const forced = plan(emptied, authentik(...people), mapping, { force: true });
    assert.equal(forced.halt, undefined);
    assert.equal(forced.actions.length, 10);
  });

  it("ignores a group last changed by someone who is not a Slack admin", () => {
    const result = plan(
      slack(full({ researchers: ["U1", "U2"] }), { UX: {} }, { researchers: "UX" }),
      authentik(
        { pk: 1, name: "a", slack: "U1", groups: ["sjanglab-researchers"] },
        { pk: 2, name: "b", slack: "U2" },
      ),
      mapping,
    );
    assert.deepEqual(result.actions, []);
    assert.match(result.warnings.join("\n"), /researchers/);
  });
});
