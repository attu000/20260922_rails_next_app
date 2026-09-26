// S6 募集詳細。URL は /student/job_postings/[id]（design/designs/API設計.md の 16-1-13）。
// [id] の部分が募集の番号になる（Django の path("job_postings/<id>") にあたる）。
// 番号が数字でない・見られない募集などの場合も、そのまま Rails に聞く。Rails が 404 を返し、画面には「見つかりません」と出る（守りは Rails。16-1-10）

import type { Metadata } from "next";
import { StudentJobPostingDetail } from "@/components/student-job-posting-detail";

export const metadata: Metadata = {
  title: "募集詳細",
};

export default async function StudentJobPostingPage({ params }: { params: Promise<{ id: string }> }) {
  // Next.js 16 では、URL の [id] の部分を await で受け取る
  const { id } = await params;
  return <StudentJobPostingDetail jobPostingId={id} />;
}
