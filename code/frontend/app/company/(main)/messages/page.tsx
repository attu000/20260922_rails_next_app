// C7 メッセージ管理（企業）。URL は /company/messages（design/designs/API設計.md の 16-1-13）。
// 開く学生のスレッドとページは ?student_id=…&page=… で持つ。中身は components/message-center.tsx。
// ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { Suspense } from "react";
import { MessageCenter } from "@/components/message-center";

export const metadata: Metadata = {
  title: "メッセージ",
};

export default function CompanyMessagesPage() {
  // URL の ? の後ろを読む部品（useSearchParams）は、Suspense で包む。
  // 包まないと、本番の組み立て（next build）が失敗する（Next.js の useSearchParams の説明書）
  return (
    <Suspense fallback={<p className="text-sm text-muted-foreground">読み込み中…</p>}>
      <MessageCenter kind="company" />
    </Suspense>
  );
}
