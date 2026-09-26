// RF-UX-004: every date is shown in the hackathon's time zone and says
// which zone it is.
export function formatInTimezone(iso: string | null | undefined, timezone: string | undefined): string {
  if (!iso) return "";

  const date = new Date(iso);
  const tz = timezone || Intl.DateTimeFormat().resolvedOptions().timeZone;

  const formatted = new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: tz,
  }).format(date);

  const zoneAbbr = new Intl.DateTimeFormat("en-US", { timeZone: tz, timeZoneName: "short" })
    .formatToParts(date)
    .find((part) => part.type === "timeZoneName")?.value;

  return zoneAbbr ? `${formatted} (${zoneAbbr})` : formatted;
}

// RF-DL-012: a hackathon can last only a few hours, so a deadline always
// shows the time, not just the day ("Sep 26, 3:30 PM").
export function formatDeadline(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(iso));
}

export function relativeTime(iso: string | null | undefined): string {
  if (!iso) return "";

  const diffMs = new Date(iso).getTime() - Date.now();
  const diffMinutes = Math.round(diffMs / 60_000);
  const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });

  if (Math.abs(diffMinutes) < 60) return rtf.format(diffMinutes, "minute");
  const diffHours = Math.round(diffMinutes / 60);
  if (Math.abs(diffHours) < 24) return rtf.format(diffHours, "hour");
  const diffDays = Math.round(diffHours / 24);
  return rtf.format(diffDays, "day");
}
