import { segmentMetadata, renderSegment } from "@/components/SegmentPage";

export const dynamic = "force-dynamic";

export async function generateMetadata() {
  return segmentMetadata("points");
}

export default async function Page() {
  return renderSegment("points");
}