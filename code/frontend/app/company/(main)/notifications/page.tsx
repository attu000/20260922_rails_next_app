// C10 通知。URL は /company/notifications（design/designs/API設計.md の 16-2-2）。
// ページは ?page=… で持つ。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { Suspense } from "react";
import { CompanyNotificationList } from "@/components/company-notification-list";

export const metadata: Metadata = {
  title: "通知",
};

export default function CompanyNotificationsPage() {
  // URL の ? の後ろを読む部品（useSearchParams）は、Suspense で包む。
  // 包まないと、本番の組み立て（next build）が失敗する（Next.js の useSearchParams の説明書）
  return (
    <Suspense fallback={<p className="text-sm text-muted-foreground">読み込み中…</p>}>
      <CompanyNotificationList />
    </Suspense>
  );
}
