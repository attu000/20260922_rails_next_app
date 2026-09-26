// 学生向けの募集の行の見た目（design/designs/ページ設計.md の 6-6 S2「各行」）。
// 募集一覧（学生のホーム）と企業詳細の募集一覧で使い回す。順5 以降の募集管理・スカウト管理でも使う。
// 業界・事業形態・工程は、順9 で Rails が返すようになってから足す。
// 「ここから条件に合いません」の区切りは、並べる側（募集一覧）が入れる

import Link from "next/link";
import { ProfileIcon } from "@/components/profile-icon";
import { buttonVariants } from "@/components/ui/button";
import { formatHourlyWage, formatWorkConditions } from "@/lib/format";
import { jobMiddleCategoryNames, type Options } from "@/lib/options";
import type { StudentJobPostingRow as Row } from "@/lib/student-job-postings";

type StudentJobPostingRowProps = {
  jobPosting: Row;
  options: Options;
};

export function StudentJobPostingRow({ jobPosting, options }: StudentJobPostingRowProps) {
  const detailHref = `/student/job_postings/${jobPosting.id}`;
  // 職種は、主な職種と関連する職種をまとめて並べる
  const jobCategoryNames = jobMiddleCategoryNames(options.masters.job_major_categories, [
    ...jobPosting.main_job_middle_category_ids,
    ...jobPosting.related_job_middle_category_ids,
  ]);
  const hourlyWage = formatHourlyWage(jobPosting.hourly_wage);

  return (
    <li className="space-y-3 rounded-lg border p-4">
      <div className="flex items-center gap-2">
        <ProfileIcon src={jobPosting.company.icon_url} name={jobPosting.company.name} size="sm" />
        <span className="text-sm text-muted-foreground">{jobPosting.company.name}</span>
      </div>

      <div className="space-y-1">
        <p className="font-bold">
          <Link href={detailHref} className="hover:underline">
            {jobPosting.title}
          </Link>
          {/* 今の募集一覧には掲載中しか出ないが、順5 以降の募集管理などで使う */}
          {!jobPosting.is_open && <span className="ml-2 text-sm font-normal text-muted-foreground">募集終了</span>}
        </p>
        {jobCategoryNames.length > 0 && (
          <p className="text-sm text-muted-foreground">{jobCategoryNames.join("・")}</p>
        )}
        <p className="text-sm">
          {formatWorkConditions(jobPosting, options)}
          {hourlyWage && ` ・ ${hourlyWage}`}
        </p>
      </div>

      <Link href={detailHref} className={buttonVariants({ variant: "outline", size: "sm" })}>
        詳細を見る
      </Link>
    </li>
  );
}
