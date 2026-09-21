import { segmentMetadata, renderSegment } from "@/components/SegmentPage";

export const dynamic = "force-dynamic";

export async function generateMetadata() {
  return segmentMetadata("no-token");
}

export default async function Page() {
  return renderSegment("no-token");
}