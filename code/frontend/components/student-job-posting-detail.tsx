"use client";

// 募集詳細（S6）の表示。詳しくは design/designs/ページ設計.md の 6-6 S6、API設計.md の 16-3 ⑲。
// 開いたら ⑲ 募集詳細と ⑦ 選択肢（表示名・マスタの名前）を取り、項目を並べる。
// 見られない募集（関係のない非公開・終了の募集、存在しない番号）は Rails が 404 を返し、「見つかりません」と出る（守りは Rails。16-1-10）。
// 自分とやりとりがある募集は、非公開・終了でも開ける（「募集終了」と出す）。
// 自分の状態の表示と「応募する」「マッチする」は components/student-candidacy-actions.tsx。
// 次のものは、それを作る順で足す（PR189）
//   - 「この企業とのメッセージ」（has_message_thread を使う）：行き先のメッセージ管理を作る順7（PR213）
//   - 業界・事業形態・工程、カルチャーグラフと自分の性格との一致・ずれ：順9・順10

import type { ReactNode } from "react";
import Link from "next/link";
import { PageTitle } from "@/components/page-title";
import { ProfileIcon } from "@/components/profile-icon";
import { StudentCandidacyActions } from "@/components/student-candidacy-actions";
import { useApi } from "@/lib/api";
import { formatHourlyWage, formatStartMonth } from "@/lib/format";
import { jobMiddleCategoryNames, labelOf, nameOf, useOptions } from "@/lib/options";
import type { StudentJobPostingDetail as Detail } from "@/lib/student-job-postings";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// 空欄の項目に出す言葉（募集一覧の稼働条件の1行表示とそろえる）
const EMPTY_TEXT = "未入力";

// 表示のまとまり（見出しと、項目の一覧）。企業詳細でも使う
export function DetailSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="space-y-3 rounded-lg border p-4">
      <h2 className="font-bold">{title}</h2>
      <dl className="space-y-3">{children}</dl>
    </section>
  );
}

// 項目1つ（名前と中身）。中身が空なら「未入力」。企業が入れた改行は、そのまま出す
export function DetailItem({ label, value }: { label: string; value: string | null }) {
  return (
    <div className="space-y-1">
      <dt className="text-sm text-muted-foreground">{label}</dt>
      <dd className="text-sm whitespace-pre-wrap">{value === null || value === "" ? EMPTY_TEXT : value}</dd>
    </div>
  );
}

// 名前の一覧を「・」でつなぐ。空なら null（「未入力」と出す）
function joinNames(names: string[]): string | null {
  return names.length > 0 ? names.join("・") : null;
}

// 「一部リモート（初月のみ出社）」のように、選んだものに補足を添える。選んでいなければ補足だけ
function withNote(main: string | null, note: string | null): string | null {
  if (main && note) return `${main}（${note}）`;
  return main ?? note;
}

export function StudentJobPostingDetail({ jobPostingId }: { jobPostingId: string }) {
  const { options, failed: optionsFailed } = useOptions();
  // mutate：覚えている中身を書き換える・取り直す関数（応募・マッチのあとに使う）
  const { data, error, mutate } = useApi<Detail>(`/api/student/job_postings/${jobPostingId}`);

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  // ⑲ が取れなかった（見られない募集なら「見つかりません」）。401 は共通の枠がログイン画面へ移すので、読み込み中のままにする
  if (!data && error && error.status !== 401) {
    return <p className="text-sm text-destructive">{error.message}</p>;
  }

  if (!options || !data) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  const majors = options.masters.job_major_categories;
  const technologyNames = data.technology_ids.flatMap((id) => nameOf(options.masters.technologies, id) ?? []);

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <PageTitle>
          {data.title}
          {/* やりとりがある非公開・終了の募集を開いたとき */}
          {!data.is_open && <span className="ml-2 text-base font-normal text-muted-foreground">募集終了</span>}
        </PageTitle>
        {/* 会社名から企業詳細へ */}
        <Link href={`/student/companies/${data.company.id}`} className="inline-flex items-center gap-2 hover:underline">
          <ProfileIcon src={data.company.icon_url} name={data.company.name} size="sm" />
          <span className="text-sm">{data.company.name}</span>
        </Link>
      </div>

      {/* 自分の状態と「応募する」「マッチする」。まず目に入るよう、タイトルと会社名のすぐ下に置く */}
      <StudentCandidacyActions
        jobPostingId={data.id}
        isOpen={data.is_open}
        status={{ my_status: data.my_status, my_candidacy_id: data.my_candidacy_id }}
        reasonOptions={options.enums.candidacy_reason}
        statusOptions={options.enums.my_status}
        // 応募・マッチができたら、返ってきた状態で書き換える（取り直しはしない）
        onStatusChanged={(status) => mutate({ ...data, ...status }, { revalidate: false })}
        // 応募・マッチができなかったら（409 など）、取り直して最新の状態にする
        onFailed={() => mutate()}
      />

      {/* 並びは、ページ設計.md の 6-6 S6 の「表示」の順 */}
      <DetailSection title="勤務地・勤務形態・時給">
        <DetailItem
          label="勤務形態"
          value={withNote(labelOf(options.enums.work_style, data.work_style), data.work_style_note)}
        />
        <DetailItem
          label="勤務地"
          value={withNote(nameOf(options.masters.prefectures, data.prefecture_id), data.work_location_note)}
        />
        <DetailItem label="時給" value={formatHourlyWage(data.hourly_wage)} />
      </DetailSection>

      <DetailSection title="職種">
        <DetailItem label="主な職種" value={joinNames(jobMiddleCategoryNames(majors, data.main_job_middle_category_ids))} />
        <DetailItem
          label="関連する職種"
          value={joinNames(jobMiddleCategoryNames(majors, data.related_job_middle_category_ids))}
        />
      </DetailSection>

      <DetailSection title="募集概要">
        {/* どんな会社か・事業内容は、募集が空欄なら Rails が企業プロフィールの値を入れて返す */}
        <DetailItem label="どんな会社か" value={data.about} />
        <DetailItem label="事業内容" value={data.business_description} />
        <DetailItem label="インターンですること" value={data.internship_details} />
        <DetailItem label="成長イメージ" value={data.growth} />
      </DetailSection>

      <DetailSection title="稼働条件">
        <DetailItem
          label="週の稼働日数"
          value={data.min_work_days_per_week === null ? null : `週${data.min_work_days_per_week}日以上`}
        />
        <DetailItem
          label="1日の稼働時間"
          value={data.min_work_hours_per_day === null ? null : `1日${data.min_work_hours_per_day}時間以上`}
        />
        <DetailItem
          label="継続期間"
          value={data.min_duration_months === null ? null : `最低${data.min_duration_months}ヶ月以上`}
        />
        <DetailItem label="開始時期" value={formatStartMonth(data.start_month)} />
        <DetailItem label="土日の勤務" value={data.weekend_ok ? "土日OK" : null} />
        <DetailItem label="備考" value={data.work_note} />
      </DetailSection>

      <DetailSection title="求める人材">
        <DetailItem label="必須要件" value={data.requirements} />
        <DetailItem label="歓迎要件" value={data.preferred_requirements} />
      </DetailSection>

      <DetailSection title="使用する言語・フレームワーク・技術">
        <DetailItem label="使用技術" value={joinNames(technologyNames)} />
        <DetailItem label="補足" value={data.technology_note} />
      </DetailSection>
    </div>
  );
}
