// C6 学生詳細。URL は /company/students/[id]（design/designs/API設計.md の 16-1-13）。
// [id] の部分が学生の番号になる。最初に選ぶ募集のタブは ?job_posting_id=… で持つ。
// 企業はすべての学生を見られる。存在しない番号は Rails が 404 を返し、「見つかりません」と出る

import type { Metadata } from "next";
import { Suspense } from "react";
import { CompanyStudentDetail } from "@/components/company-student-detail";

export const metadata: Metadata = {
  title: "学生詳細",
};

export default async function CompanyStudentPage({ params }: { params: Promise<{ id: string }> }) {
  // Next.js 16 では、URL の [id] の部分を await で受け取る
  const { id } = await params;
  // URL の ? の後ろを読む部品（useSearchParams）は、Suspense で包む。
  // 包まないと、本番の組み立て（next build）が失敗する（Next.js の useSearchParams の説明書）
  return (
    <Suspense fallback={<p className="text-sm text-muted-foreground">読み込み中…</p>}>
      <CompanyStudentDetail studentId={id} />
    </Suspense>
  );
}
