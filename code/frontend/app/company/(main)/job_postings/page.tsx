// C2 募集一覧（企業のホーム）。URL は /company/job_postings（design/designs/API設計.md の 16-1-13）。
// Phase 5 では、ログイン後の移動先として置いている仮の画面。中身は Phase 6 で作る

import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "募集一覧",
};

export default function CompanyJobPostingsPage() {
  return <p className="text-sm">募集一覧（企業のホーム）は Phase 6 で作ります。</p>;
}
