// C2 募集一覧（企業のホーム）。URL は /company/job_postings（design/designs/API設計.md の 16-1-13）。
// ログイン後の移動先で、ヘッダーの「募集管理」タブの行き先。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { JobPostingList } from "@/components/job-posting-list";

export const metadata: Metadata = {
  title: "募集一覧",
};

export default function CompanyJobPostingsPage() {
  return <JobPostingList />;
}
