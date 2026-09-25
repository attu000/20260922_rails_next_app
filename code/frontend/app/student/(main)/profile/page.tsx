// S1 マイページ（学生プロフィール編集）。URL は /student/profile（design/designs/API設計.md の 16-1-13）。
// ヘッダーの「マイページ」タブの行き先。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { StudentProfileForm } from "@/components/student-profile-form";

export const metadata: Metadata = {
  title: "マイページ",
};

export default function StudentProfilePage() {
  return <StudentProfileForm />;
}
