"use client";

// 企業詳細（S7）の表示。詳しくは design/designs/ページ設計.md の 6-6 S7、API設計.md の 16-3 ⑳。
// 開いたら ⑳ 企業詳細と ⑦ 選択肢（業界・事業形態の名前、人数の表示名）を取り、企業のプロフィールと掲載中の募集を並べる。
// 業界・事業形態は企業プロフィールの値（募集の値ではない）。
// 「この企業とのメッセージ」は、順6 で足す（PR189）

import { PageTitle } from "@/components/page-title";
import { ProfileIcon } from "@/components/profile-icon";
import { DetailItem, DetailSection } from "@/components/student-job-posting-detail";
import { StudentJobPostingRow } from "@/components/student-job-posting-row";
import { useApi } from "@/lib/api";
import { labelOf, nameOf, useOptions } from "@/lib/options";
import type { StudentCompany } from "@/lib/student-job-postings";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

export function StudentCompanyDetail({ companyId }: { companyId: string }) {
  const { options, failed: optionsFailed } = useOptions();
  const { data, error } = useApi<StudentCompany>(`/api/student/companies/${companyId}`);

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  // ⑳ が取れなかった（存在しない番号なら「見つかりません」）。401 は共通の枠がログイン画面へ移すので、読み込み中のままにする
  if (!data && error && error.status !== 401) {
    return <p className="text-sm text-destructive">{error.message}</p>;
  }

  if (!options || !data) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  // 名前の一覧を「・」でつなぐ。空なら null（「未入力」と出す）
  const industryNames = data.industry_ids.flatMap((id) => nameOf(options.masters.industries, id) ?? []);
  const businessTypeNames = data.business_type_ids.flatMap((id) => nameOf(options.masters.business_types, id) ?? []);

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <ProfileIcon src={data.icon_url} name={data.name} size="lg" />
        <PageTitle>{data.name}</PageTitle>
      </div>

      {/* 並びは、ページ設計.md の 6-6 S7 の「表示」の順 */}
      <DetailSection title="会社のプロフィール">
        <DetailItem label="業界" value={industryNames.length > 0 ? industryNames.join("・") : null} />
        <DetailItem label="事業形態" value={businessTypeNames.length > 0 ? businessTypeNames.join("・") : null} />
        <DetailItem label="事業内容" value={data.business_description} />
        <DetailItem label="人数" value={labelOf(options.enums.employee_size, data.employee_size)} />
        <DetailItem label="どんな会社か" value={data.about} />
      </DetailSection>

      <section className="space-y-3">
        <h2 className="font-bold">掲載中の募集</h2>
        {data.job_postings.length === 0 ? (
          <p className="text-sm text-muted-foreground">掲載中の募集はありません</p>
        ) : (
          // 募集一覧（学生のホーム）と同じ行の部品を使い回す
          <ul className="space-y-3">
            {data.job_postings.map((jobPosting) => (
              <StudentJobPostingRow key={jobPosting.id} jobPosting={jobPosting} options={options} />
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
