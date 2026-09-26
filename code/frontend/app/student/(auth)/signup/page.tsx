// S9 新規登録（学生用）。URL は /student/signup（design/designs/API設計.md の 16-1-13）。
// ログイン済みで開いたら、共通の枠（(auth)/layout.tsx）が種別ごとのホームへ移す。中身は components/student-signup-form.tsx

import type { Metadata } from "next";
import { StudentSignupForm } from "@/components/student-signup-form";

export const metadata: Metadata = {
  title: "新規登録（学生用）",
};

export default function StudentSignupPage() {
  return <StudentSignupForm />;
}
