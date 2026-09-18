import { getDeadlineStatus } from "@/lib/date-utils";

export default function DeadlineBadge({ deadline, date }: { deadline?: string; date?: string }) {
  const status = getDeadlineStatus(deadline, date);
  if (!status) return null;
  return (
    <span className={"deadline-badge deadline-badge-" + status}>
      {status === "ending-soon" ? "Ending Soon" : "Ended"}
    </span>
  );
}