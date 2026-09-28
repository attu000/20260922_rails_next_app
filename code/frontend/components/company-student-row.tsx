// 企業向けの学生の行の見た目（形C。design/designs/ページ設計.md の 6-5 C5「各行」）。
// 学生検索と、学生詳細のスカウト送信後のポップアップ（この学生に似た学生。順14。PR319）で使い回す。
// 「ここから条件に合いません」の区切りは、並べる側（学生検索）が入れる

import Link from "next/link";
import { ProfileIcon } from "@/components/profile-icon";
import { StatusBadge } from "@/components/status-badge";
import { buttonVariants } from "@/components/ui/button";
import type { CompanyStudentRow as Row } from "@/lib/company-students";
import { jobMiddleCategoryNames, labelOf, nameOf, type Options } from "@/lib/options";

type CompanyStudentRowProps = {
  student: Row;
  options: Options;
  // 学生詳細を開くときに選んでおく募集。null なら指定しない（学生詳細は先頭の募集を選ぶ）
  jobPostingId: string | null;
  // 名前の横に出す札。null なら出さない
  tag: string | null;
};

// 名前（と札）、学年・卒業年度・活動状況、興味のある職種、プログラミング歴、稼働条件と、「詳細を見る」
export function CompanyStudentRow({ student, options, jobPostingId, tag }: CompanyStudentRowProps) {
  // 学生詳細。募集を指定していれば、その募集を選んだ状態で開く
  const detailHref = `/company/students/${student.id}${
    jobPostingId === null ? "" : `?job_posting_id=${encodeURIComponent(jobPostingId)}`
  }`;
  // 学年・卒業年度・活動状況。空欄の項目は飛ばす
  const profileParts = [
    labelOf(options.enums.grade, student.grade),
    student.graduation_year === null ? null : `${student.graduation_year}年卒`,
    labelOf(options.enums.activity_status, student.activity_status),
  ].filter((part) => part !== null);
  const jobCategoryNames = jobMiddleCategoryNames(
    options.masters.job_major_categories,
    student.interested_job_middle_category_ids,
  );
  // プログラミング歴。「Ruby（v3）」のように、技術の名前（なければ「その他」の名前）とレベル
  const skillNames = student.skills.map(
    (skill) => `${nameOf(options.masters.technologies, skill.technology_id) ?? skill.other_name ?? ""}（${skill.level}）`,
  );
  // 稼働条件。学生が入れているのは上限なので「まで」「以上続けられる」を付ける（学生詳細と同じ書き方）。空欄は飛ばす
  const workConditionParts = [
    student.work_days_per_week === null ? null : `週${student.work_days_per_week}日まで`,
    student.work_hours_per_day === null ? null : `1日${student.work_hours_per_day}時間まで`,
    student.duration_months === null ? null : `${student.duration_months}ヶ月以上`,
  ].filter((part) => part !== null);

  return (
    <li className="space-y-3 rounded-lg border p-4">
      <div className="flex flex-wrap items-center gap-2">
        <ProfileIcon src={student.icon_url} name={student.name} size="sm" />
        <Link href={detailHref} className="font-bold hover:underline">
          {student.name}
        </Link>
        {/* 見た目は、候補者一覧の行のタグとそろえる（同じ部品） */}
        {tag && <StatusBadge size="sm">{tag}</StatusBadge>}
      </div>

      <div className="space-y-1 text-sm">
        {profileParts.length > 0 && <p className="text-muted-foreground">{profileParts.join(" ・ ")}</p>}
        {jobCategoryNames.length > 0 && <p>興味のある職種：{jobCategoryNames.join("・")}</p>}
        {skillNames.length > 0 && <p>プログラミング歴：{skillNames.join("・")}</p>}
        {workConditionParts.length > 0 && <p>稼働条件：{workConditionParts.join("・")}</p>}
      </div>

      <Link href={detailHref} className={buttonVariants({ variant: "outline", size: "sm" })}>
        詳細を見る
      </Link>
    </li>
  );
}
