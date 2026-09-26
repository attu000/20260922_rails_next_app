// C9 新規登録（企業用）。URL は /company/signup（design/designs/API設計.md の 16-1-13）。
// ログイン済みで開いたら、共通の枠（(auth)/layout.tsx）が種別ごとのホームへ移す。中身は components/company-signup-form.tsx

import type { Metadata } from "next";
import { CompanySignupForm } from "@/components/company-signup-form";

export const metadata: Metadata = {
  title: "新規登録（企業用）",
};

export default function CompanySignupPage() {
  return <CompanySignupForm />;
}
