"use client";

// プチ職業体験一覧（S11）の中身。詳しくは design/designs/ページ設計.md の S11、API設計.md の 16-3-9 ㊺。
// 開いたら ㊺ 講座の一覧と ⑦ 選択肢（中分類・工程の名前）を取り、講座の表示順に並べる。
// 修了済み（自己分析を送った）かは Rails が判定して返したものをそのまま使う（16-1-9）

import Link from "next/link";
import { PageTitle } from "@/components/page-title";
import { StatusBadge } from "@/components/status-badge";
import { useApi } from "@/lib/api";
import type { JobTrialList } from "@/lib/job-trials";
import { jobMiddleCategoryNames, namesOf, useOptions } from "@/lib/options";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

export function StudentJobTrialList() {
  const { options, failed: optionsFailed } = useOptions();
  const { data, error } = useApi<JobTrialList>("/api/student/job_trials");

  let content;
  if (optionsFailed) {
    content = <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  } else if (!data && error && error.status !== 401) {
    // 401 は共通の枠がログイン画面へ移すので、読み込み中のままにする
    content = <p className="text-sm text-destructive">{error.message}</p>;
  } else if (!options || !data) {
    content = <p className="text-sm text-muted-foreground">読み込み中…</p>;
  } else if (data.items.length === 0) {
    content = <p className="text-sm text-muted-foreground">講座はまだありません</p>;
  } else {
    const { masters } = options;
    content = (
      <ul className="space-y-3">
        {data.items.map((jobTrial) => {
          // 「中分類 ／ 工程・工程」の1行（募集の行と同じ書き方）
          const summary = [
            jobMiddleCategoryNames(masters.job_major_categories, [jobTrial.job_middle_category_id]).join("・"),
            namesOf(masters.work_processes, jobTrial.work_process_ids).join("・"),
          ]
            .filter((names) => names !== "")
            .join(" ／ ");
          return (
            <li key={jobTrial.id} className="space-y-1 rounded-lg border p-4">
              <p className="font-bold">
                <Link href={`/student/job_trials/${jobTrial.id}`} className="hover:underline">
                  {jobTrial.title}
                </Link>
                {/* 見た目は、募集の「応募済み」の札とそろえる（同じ部品） */}
                {jobTrial.completed && (
                  <StatusBadge size="sm" className="ml-2">
                    修了済み
                  </StatusBadge>
                )}
              </p>
              {summary !== "" && <p className="text-sm text-muted-foreground">{summary}</p>}
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <div className="space-y-6">
      <PageTitle>プチ職業体験</PageTitle>
      {content}
    </div>
  );
}
