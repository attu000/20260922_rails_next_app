// C5 学生検索。URL は /company/students（design/designs/API設計.md の 16-1-13）。
// 選んだ募集・並び順・ページは ?job_posting_id=…&sort=…&page=… で持つ。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { Suspense } from "react";
import { CompanyStudentSearch } from "@/components/company-student-search";

export const metadata: Metadata = {
  title: "学生検索",
};

export default function CompanyStudentsPage() {
  // URL の ? の後ろを読む部品（useSearchParams）は、Suspense で包む。
  // 包まないと、本番の組み立て（next build）が失敗する（Next.js の useSearchParams の説明書）
  return (
    <Suspense fallback={<p className="text-sm text-muted-foreground">読み込み中…</p>}>
      <CompanyStudentSearch />
    </Suspense>
  );
}
