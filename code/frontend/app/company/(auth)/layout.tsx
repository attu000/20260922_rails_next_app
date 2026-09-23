// 企業のログイン前の画面（ログイン、新規登録）の共通の枠。
// ログイン済みで開いたら、種別ごとのホームへ移す（design/designs/API設計.md の 16-1-6）

import type { ReactNode } from "react";
import { GuestOnly } from "@/components/guest-only";

export default function CompanyAuthLayout({ children }: { children: ReactNode }) {
  return <GuestOnly>{children}</GuestOnly>;
}
