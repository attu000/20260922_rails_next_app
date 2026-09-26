// S7 企業詳細。URL は /student/companies/[id]（design/designs/API設計.md の 16-1-13）。
// [id] の部分が企業の番号になる。学生はすべての企業を見られる。存在しない番号は Rails が 404 を返し、「見つかりません」と出る

import type { Metadata } from "next";
import { StudentCompanyDetail } from "@/components/student-company-detail";

export const metadata: Metadata = {
  title: "企業詳細",
};

export default async function StudentCompanyPage({ params }: { params: Promise<{ id: string }> }) {
  // Next.js 16 では、URL の [id] の部分を await で受け取る
  const { id } = await params;
  return <StudentCompanyDetail companyId={id} />;
}
