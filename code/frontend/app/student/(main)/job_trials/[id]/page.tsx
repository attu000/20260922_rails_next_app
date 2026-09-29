// S12 プチ職業体験。URL は /student/job_trials/[id]（design/designs/API設計.md の 16-1-13）。
// [id] の部分が講座の番号になる（Django の path("job_trials/<id>") にあたる）。
// 講座と自己分析を、この1つの URL の中のステップで進む（PR388）。中身は components/student-job-trial.tsx。
// 存在しない番号は Rails が 404 を返し、画面には「見つかりません」と出る（守りは Rails。16-1-10）

import type { Metadata } from "next";
import { StudentJobTrial } from "@/components/student-job-trial";

export const metadata: Metadata = {
  title: "プチ職業体験",
};

export default async function StudentJobTrialPage({ params }: { params: Promise<{ id: string }> }) {
  // Next.js 16 では、URL の [id] の部分を await で受け取る
  const { id } = await params;
  return <StudentJobTrial jobTrialId={id} />;
}
