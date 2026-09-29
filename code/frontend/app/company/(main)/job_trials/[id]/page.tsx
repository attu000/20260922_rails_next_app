// C11 プチ職業体験の内容。URL は /company/job_trials/[id]（design/designs/API設計.md の 16-1-13）。
// [id] の部分が講座の番号になる（Django の path("job_trials/<id>") にあたる）。
// 入口は募集詳細編集の講座名と、学生詳細の自己分析のポップアップの「講座の内容を見る」で、どちらも新しいタブで開く。
// 講座の一覧の画面は作らない（入口が2か所だけで、そこからのリンクで足りるため）。中身は components/company-job-trial.tsx。
// 存在しない番号は Rails が 404 を返し、画面には「見つかりません」と出る（守りは Rails。16-1-10）

import type { Metadata } from "next";
import { CompanyJobTrial } from "@/components/company-job-trial";

export const metadata: Metadata = {
  title: "プチ職業体験の内容",
};

export default async function CompanyJobTrialPage({ params }: { params: Promise<{ id: string }> }) {
  // Next.js 16 では、URL の [id] の部分を await で受け取る
  const { id } = await params;
  return <CompanyJobTrial jobTrialId={id} />;
}
