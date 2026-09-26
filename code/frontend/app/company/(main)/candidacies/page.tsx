// C4 候補者一覧。URL は /company/candidacies（design/designs/API設計.md の 16-1-13）。
// 募集別のタブとページは ?job_posting_id=…&page=… で持つ。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { Suspense } from "react";
import { CompanyCandidacyList } from "@/components/company-candidacy-list";

export const metadata: Metadata = {
  title: "候補者一覧",
};

export default function CompanyCandidaciesPage() {
  // URL の ? の後ろを読む部品（useSearchParams）は、Suspense で包む。
  // 包まないと、本番の組み立て（next build）が失敗する（Next.js の useSearchParams の説明書）
  return (
    <Suspense fallback={<p className="text-sm text-muted-foreground">読み込み中…</p>}>
      <CompanyCandidacyList />
    </Suspense>
  );
}
