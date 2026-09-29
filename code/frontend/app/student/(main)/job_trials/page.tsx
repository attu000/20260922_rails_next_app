// S11 プチ職業体験一覧。URL は /student/job_trials（design/designs/API設計.md の 16-1-13）。
// 中身は components/student-job-trial-list.tsx。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { StudentJobTrialList } from "@/components/student-job-trial-list";

export const metadata: Metadata = {
  title: "プチ職業体験",
};

export default function StudentJobTrialsPage() {
  return <StudentJobTrialList />;
}
