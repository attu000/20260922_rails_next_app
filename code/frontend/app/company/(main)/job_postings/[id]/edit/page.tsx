// C3 募集詳細編集（編集）。URL は /company/job_postings/[id]/edit（design/designs/API設計.md の 16-1-13）。
// [id] の部分が募集の番号になる（Django の path("job_postings/<id>/edit") にあたる）。
// 番号が数字でない・他社の募集などの場合も、そのまま Rails に聞く。Rails が 404 を返し、画面には「見つかりません」と出る（守りは Rails。16-1-10）

import type { Metadata } from "next";
import { JobPostingForm } from "@/components/job-posting-form";

export const metadata: Metadata = {
  title: "募集詳細編集",
};

export default async function EditJobPostingPage({ params }: { params: Promise<{ id: string }> }) {
  // Next.js 16 では、URL の [id] の部分を await で受け取る
  const { id } = await params;
  return <JobPostingForm jobPostingId={id} />;
}
