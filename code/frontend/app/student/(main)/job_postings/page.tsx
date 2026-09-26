// S2 募集一覧（学生のホーム。募集検索）。URL は /student/job_postings（design/designs/API設計.md の 16-1-13）。
// 検索の条件・並び順・ページは ?q=…&sort=…&page=… で持つ。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { Suspense } from "react";
import { StudentJobPostingSearch } from "@/components/student-job-posting-search";

export const metadata: Metadata = {
  title: "募集一覧",
};

export default function StudentJobPostingsPage() {
  // URL の ? の後ろを読む部品（useSearchParams）は、Suspense で包む。
  // 包まないと、本番の組み立て（next build）が失敗する（Next.js の useSearchParams の説明書）
  return (
    <Suspense fallback={<p className="text-sm text-muted-foreground">読み込み中…</p>}>
      <StudentJobPostingSearch />
    </Suspense>
  );
}
