// S4 スカウト管理。URL は /student/scouts（design/designs/API設計.md の 16-1-13）。
// 中身は募集管理と同じ部品（components/student-candidacy-list.tsx）。
// ページは ?page=… で持つ。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { Suspense } from "react";
import { StudentCandidacyList } from "@/components/student-candidacy-list";

export const metadata: Metadata = {
  title: "スカウト管理",
};

export default function StudentScoutsPage() {
  // URL の ? の後ろを読む部品（useSearchParams）は、Suspense で包む。
  // 包まないと、本番の組み立て（next build）が失敗する（Next.js の useSearchParams の説明書）
  return (
    <Suspense fallback={<p className="text-sm text-muted-foreground">読み込み中…</p>}>
      <StudentCandidacyList kind="scouts" />
    </Suspense>
  );
}
