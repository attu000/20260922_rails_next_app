"use client";

// 募集一覧（C2。企業のホーム）の中身。詳しくは design/designs/ページ設計.md の 6-5 C2、API設計.md の 16-3 ⑪。
// 開いたら ⑪ 自社の募集の一覧と ⑦ 選択肢（状態の表示名）を取り、行を並べる。並び順は Rails が決める（最終更新の新しい順）。
// 「この募集でスカウト先を探す」は【強み】、未対応の応募の件数は【仕上げ】で足す

import Link from "next/link";
import { PageTitle } from "@/components/page-title";
import { buttonVariants } from "@/components/ui/button";
import { useApi } from "@/lib/api";
import { formatDate } from "@/lib/format";
import type { JobPostingRow } from "@/lib/job-postings";
import { labelOf, useOptions } from "@/lib/options";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

export function JobPostingList() {
  const { options, failed: optionsFailed } = useOptions();
  // 401 は共通の枠（member-only.tsx）がログイン画面へ移す
  const { data, error } = useApi<{ items: JobPostingRow[] }>("/api/company/job_postings");

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  if (!data && error && error.status !== 401) {
    return <p className="text-sm text-destructive">{error.message}</p>;
  }

  if (!options || !data) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <PageTitle>募集一覧</PageTitle>
        {/* 画面の移動だけのボタンは、ボタンの見た目をしたリンクにする（新しいタブでも開ける） */}
        <Link href="/company/job_postings/new" className={buttonVariants()}>
          募集新規作成
        </Link>
      </div>

      {data.items.length === 0 ? (
        <p className="text-sm text-muted-foreground">まだ募集がありません</p>
      ) : (
        <ul className="space-y-3">
          {data.items.map((jobPosting) => (
            <li key={jobPosting.id} className="space-y-3 rounded-lg border p-4">
              <div className="space-y-1">
                <p className="font-bold">{jobPosting.title}</p>
                <p className="text-sm text-muted-foreground">
                  {/* 状態は Rails が返した表示名を使う（16-1-9） */}
                  {labelOf(options.enums.job_posting_status, jobPosting.status)}
                  {" ・ "}
                  最初に掲載した日：
                  {jobPosting.published_at ? formatDate(jobPosting.published_at) : "未掲載"}
                  {" ・ "}
                  最終更新日：{formatDate(jobPosting.updated_at)}
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <Link
                  href={`/company/job_postings/${jobPosting.id}/edit`}
                  className={buttonVariants({ variant: "outline", size: "sm" })}
                >
                  編集する
                </Link>
                {/* 候補者一覧（C4）を、この募集のタブを選んだ状態で開く */}
                <Link
                  href={`/company/candidacies?job_posting_id=${jobPosting.id}`}
                  className={buttonVariants({ variant: "outline", size: "sm" })}
                >
                  この募集の候補者を見る
                </Link>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
