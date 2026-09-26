"use client";

// 募集管理（S3）とスカウト管理（S4）の中身。
// 詳しくは design/designs/ページ設計.md の 6-6 S3・S4、API設計.md の 16-3 ㉞㉟・16-1-11。
// 2つは、見出し・URL・1件もないときの文だけが違い、行の形（形B ＋ やりとりの番号と自分の状態）は同じなので、1つの部品で出す。
//   - 募集管理：応募した募集（状態は問わない）と、スカウトからマッチした募集
//   - スカウト管理：届いたスカウトのうち、まだマッチしていないもの（企業に見送られていても、学生には「スカウトあり」のまま）
// どちらも、やりとりが始まった日の新しい順に並べる（Rails が選んで並べる）。
// 企業側で見送り・合格・不合格になっていても、Rails が「応募済み」「スカウトあり」「マッチ済み」のまま返す。
// 各行から開くのは募集詳細（スカウト文は、そこの「この企業とのメッセージ」から読む。メッセージへの直接の導線は作らない）。
// ページは URL の ?page= に持つ（URL が正。16-1-13）。
// 募集管理の、応募済み／マッチ済みで絞るタグの切り替え（?status=）は【仕上げ】で足す

import type { ReactNode } from "react";
import { useSearchParams } from "next/navigation";
import { PageNav } from "@/components/page-nav";
import { PageTitle } from "@/components/page-title";
import { StudentJobPostingRow } from "@/components/student-job-posting-row";
import { useApi } from "@/lib/api";
import { labelOf, useOptions } from "@/lib/options";
import type { StudentCandidacyListResult } from "@/lib/student-job-postings";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// 一覧の種類ごとの違い
const LIST_SETTINGS = {
  candidacies: {
    title: "募集管理",
    pagePath: "/student/candidacies",
    apiPath: "/api/student/candidacies",
    emptyMessage: "応募した募集はまだありません",
  },
  scouts: {
    title: "スカウト管理",
    pagePath: "/student/scouts",
    apiPath: "/api/student/scouts",
    emptyMessage: "届いているスカウトはありません",
  },
} as const;

type StudentCandidacyListProps = {
  // "candidacies"（募集管理）か "scouts"（スカウト管理）
  kind: keyof typeof LIST_SETTINGS;
};

export function StudentCandidacyList({ kind }: StudentCandidacyListProps) {
  const settings = LIST_SETTINGS[kind];
  const searchParams = useSearchParams();
  // URL の ?page= を読む。数でなければ1ページ目（Rails も同じ扱い）
  const requestedPage = Number(searchParams.get("page"));
  const page = Number.isInteger(requestedPage) && requestedPage > 1 ? requestedPage : 1;
  const { options, failed: optionsFailed } = useOptions();
  // 401 は共通の枠（member-only.tsx）がログイン画面へ移す。
  // keepPreviousData：次のページが届くまで前のページを出したままにする（ページ送りで画面がちらつかないように）
  const { data, error } = useApi<StudentCandidacyListResult>(
    `${settings.apiPath}${page > 1 ? `?page=${page}` : ""}`,
    { keepPreviousData: true },
  );

  // ページ番号 → 画面の URL。1ページ目は ?page= を付けない
  function pageUrl(nextPage: number): string {
    return nextPage > 1 ? `${settings.pagePath}?page=${nextPage}` : settings.pagePath;
  }

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  let content: ReactNode;
  if (!data && error && error.status !== 401) {
    content = <p className="text-sm text-destructive">{error.message}</p>;
  } else if (!options || !data) {
    content = <p className="text-sm text-muted-foreground">読み込み中…</p>;
  } else if (data.pagination.total_count === 0) {
    content = <p className="text-sm text-muted-foreground">{settings.emptyMessage}</p>;
  } else if (data.items.length === 0) {
    // 範囲外のページ（URL を手で書き換えたときなど）
    content = <p className="text-sm text-muted-foreground">このページに募集はありません</p>;
  } else {
    content = (
      <>
        {/* 募集一覧（学生のホーム）と同じ行の部品に、「応募済み」「スカウトあり」「マッチ済み」の札を付ける */}
        <ul className="space-y-3">
          {data.items.map((item) => (
            <StudentJobPostingRow
              key={item.candidacy_id}
              jobPosting={item}
              options={options}
              tag={labelOf(options.enums.my_status, item.my_status)}
            />
          ))}
        </ul>
        <PageNav page={data.pagination.page} totalPages={data.pagination.total_pages} hrefFor={pageUrl} />
      </>
    );
  }

  return (
    <div className="space-y-6">
      <PageTitle>{settings.title}</PageTitle>
      {content}
    </div>
  );
}
