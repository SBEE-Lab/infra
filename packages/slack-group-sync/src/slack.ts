/**
 * Reads the Slack side of a reconcile: the user groups with their members and
 * last editor, and every user's active and admin flags.
 */

import type { WebClient } from "@slack/web-api";
import { z } from "zod";

import type { SlackState, SlackUser } from "./plan.ts";

const usergroups = z.object({
  usergroups: z.array(
    z.looseObject({
      handle: z.string(),
      updated_by: z.string(),
      users: z.array(z.string()).default([]),
    }),
  ),
});

const usersPage = z.object({
  members: z.array(
    z.looseObject({
      id: z.string(),
      deleted: z.boolean().default(false),
      is_admin: z.boolean().default(false),
      is_owner: z.boolean().default(false),
      is_primary_owner: z.boolean().default(false),
    }),
  ),
  response_metadata: z.looseObject({ next_cursor: z.string().default("") }).optional(),
});

export async function readSlack(client: WebClient): Promise<SlackState> {
  const groups = usergroups.parse(
    await client.usergroups.list({ include_users: true, include_disabled: false }),
  );
  const users = new Map<string, SlackUser>();
  let cursor = "";
  do {
    const page = usersPage.parse(
      await client.users.list({ limit: 200, ...(cursor ? { cursor } : {}) }),
    );
    for (const member of page.members) {
      users.set(member.id, {
        deleted: member.deleted,
        admin: member.is_admin || member.is_owner || member.is_primary_owner,
      });
    }
    cursor = page.response_metadata?.next_cursor ?? "";
  } while (cursor);
  return {
    groups: groups.usergroups.map((group) => ({
      handle: group.handle,
      members: group.users,
      updatedBy: group.updated_by,
    })),
    users,
  };
}
