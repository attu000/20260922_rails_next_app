// C8 ログイン（企業用）。URL は /company/login（design/designs/API設計.md の 16-1-13）

import type { Metadata } from "next";
import { Suspense } from "react";
import { LoginForm } from "@/components/login-form";

export const metadata: Metadata = {
  title: "ログイン（企業用）",
};

export default function CompanyLoginPage() {
  // LoginForm は URL の ? の後ろ（return_to）を読むので、Suspense で囲む。
  // 囲まないと、本番の組み立て（next build）が失敗する（Next.js の説明書の useSearchParams の章）
  return (
    <Suspense>
      <LoginForm role="company" />
    </Suspense>
  );
}
