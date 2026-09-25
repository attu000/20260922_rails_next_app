// C3 募集詳細編集（新規）。URL は /company/job_postings/new（design/designs/API設計.md の 16-1-13）。
// 募集一覧の「募集新規作成」の行き先。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { JobPostingForm } from "@/components/job-posting-form";

export const metadata: Metadata = {
  title: "募集新規作成",
};

export default function NewJobPostingPage() {
  // 番号なし → 新規作成
  return <JobPostingForm jobPostingId={null} />;
}
