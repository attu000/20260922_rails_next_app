// C1 企業プロフィール編集。URL は /company/profile（design/designs/API設計.md の 16-1-13）。
// ヘッダーの「会社情報」タブの行き先。ログインの確認とヘッダーは、共通の枠（(main)/layout.tsx）が付ける

import type { Metadata } from "next";
import { CompanyProfileForm } from "@/components/company-profile-form";

export const metadata: Metadata = {
  title: "企業プロフィール編集",
};

export default function CompanyProfilePage() {
  return <CompanyProfileForm />;
}
