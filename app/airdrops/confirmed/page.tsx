import { segmentMetadata, renderSegment } from "@/components/SegmentPage";

export const dynamic = "force-dynamic";

export async function generateMetadata() {
  return segmentMetadata("confirmed");
}

export default async function Page() {
  return renderSegment("confirmed");
}