// 企業のログイン後の画面（C1〜C7、C10）の共通の枠。
// 未ログインならログイン画面へ、学生なら学生のホームへ移す（design/designs/API設計.md の 16-1-6）。
// このフォルダに置いた画面には、この枠とヘッダーが自動で付く

import type { ReactNode } from "react";
import { AppHeader } from "@/components/app-header";
import { MemberOnly } from "@/components/member-only";

export default function CompanyMainLayout({ children }: { children: ReactNode }) {
  return (
    <MemberOnly role="company">
      <AppHeader />
      <main className="p-4">{children}</main>
    </MemberOnly>
  );
}
