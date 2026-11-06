/**
 * When the safety-net reconciles run: the next of a few local times of day,
 * computed in the configured time zone rather than the host's.
 */

/** Milliseconds until the next of `times` (HH:MM) in `timezone`. */
export function untilNext(times: readonly string[], timezone: string, now = new Date()): number {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-GB", {
      timeZone: timezone,
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23",
    })
      .formatToParts(now)
      .map((part) => [part.type, part.value]),
  );
  const nowSeconds = Number(parts.hour) * 3600 + Number(parts.minute) * 60 + Number(parts.second);
  const waits = times.map((time) => {
    const [h, m] = time.split(":").map(Number) as [number, number];
    const wait = h * 3600 + m * 60 - nowSeconds;
    return wait > 0 ? wait : wait + 86_400;
  });
  return Math.min(...waits) * 1000;
}
