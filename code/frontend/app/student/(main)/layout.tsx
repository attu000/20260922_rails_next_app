// 学生のログイン後の画面（S1〜S7）の共通の枠。
// 未ログインならログイン画面へ、企業なら企業のホームへ移す（design/designs/API設計.md の 16-1-6）。
// このフォルダに置いた画面には、この枠とヘッダーが自動で付く

import type { ReactNode } from "react";
import { AppHeader } from "@/components/app-header";
import { MemberOnly } from "@/components/member-only";

export default function StudentMainLayout({ children }: { children: ReactNode }) {
  return (
    <MemberOnly role="student">
      <AppHeader />
      <main className="p-4">{children}</main>
    </MemberOnly>
  );
}
