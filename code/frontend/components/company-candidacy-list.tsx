"use client";

// 候補者一覧（C4）の中身。詳しくは design/designs/ページ設計.md の 6-5 C4、API設計.md の 16-3 ㉑・16-1-11。
// 自社の募集への応募・スカウトを、1件1行で、やりとりが始まった日の新しい順に並べる（Rails が選んで並べる）。
// タブ（「すべて」と募集別）とページは、URL の ?job_posting_id= と ?page= に持つ（URL が正。16-1-13）。
// 企業の募集一覧の「この募集の候補者を見る」から来たときは、その募集のタブが選ばれた状態で開く。
// マッチ以降の行には「メッセージ」のボタンを出す。出すかは Rails の after_match に従う（PR209・PR224）。
// 次のものは、それを作る順で足す
//   - 見送り・合格・不合格を既定で隠す切り替え（?show_all=true）：順11
//   - 未返信のタグ：【仕上げ】

import type { ReactNode } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { PageNav } from "@/components/page-nav";
import { PageTitle } from "@/components/page-title";
import { ProfileIcon } from "@/components/profile-icon";
import { StatusBadge } from "@/components/status-badge";
import { buttonVariants } from "@/components/ui/button";
import { useApi } from "@/lib/api";
import type { CompanyCandidacyListResult, CompanyCandidacyRow } from "@/lib/company-candidacies";
import { formatDate } from "@/lib/format";
import type { JobPostingRow } from "@/lib/job-postings";
import { labelOf, type Options, useOptions } from "@/lib/options";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

const PAGE_PATH = "/company/candidacies";

// タブ（募集の番号。「すべて」なら null）とページ → ? の後ろ。1ページ目は page を付けない
function buildQuery(jobPostingId: string | null, page: number): string {
  const params = new URLSearchParams();
  if (jobPostingId !== null) params.set("job_posting_id", jobPostingId);
  if (page > 1) params.set("page", String(page));
  return params.toString();
}

// ? の後ろ → 画面の URL
function pageUrl(query: string): string {
  return query === "" ? PAGE_PATH : `${PAGE_PATH}?${query}`;
}

export function CompanyCandidacyList() {
  const searchParams = useSearchParams();
  // 選んでいるタブ。URL の番号は利用者が書き換えられるが、そのまま Rails に渡す（他社や存在しない番号なら Rails が 404）
  const jobPostingId = searchParams.get("job_posting_id") || null;
  // URL の ?page= を読む。数でなければ1ページ目（Rails も同じ扱い）
  const requestedPage = Number(searchParams.get("page"));
  const page = Number.isInteger(requestedPage) && requestedPage > 1 ? requestedPage : 1;
  const query = buildQuery(jobPostingId, page);

  const { options, failed: optionsFailed } = useOptions();
  // タブに出す募集の名前（⑪ 自社の全募集。募集一覧と同じ、最終更新の新しい順）
  const { data: jobPostings } = useApi<{ items: JobPostingRow[] }>("/api/company/job_postings");
  // 401 は共通の枠（member-only.tsx）がログイン画面へ移す。
  // keepPreviousData：次の結果が届くまで前の結果を出したままにする（タブやページを変えたときに画面がちらつかないように）
  const { data, error } = useApi<CompanyCandidacyListResult>(`/api/company/candidacies${query === "" ? "" : `?${query}`}`, {
    keepPreviousData: true,
  });

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  let content: ReactNode;
  if (!data && error && error.status !== 401) {
    // 他社の募集や存在しない募集の番号を URL に入れたときは「見つかりません」
    content = <p className="text-sm text-destructive">{error.message}</p>;
  } else if (!options || !data) {
    content = <p className="text-sm text-muted-foreground">読み込み中…</p>;
  } else if (data.pagination.total_count === 0) {
    content = <p className="text-sm text-muted-foreground">まだ応募・スカウトはありません</p>;
  } else if (data.items.length === 0) {
    // 範囲外のページ（URL を手で書き換えたときなど）
    content = <p className="text-sm text-muted-foreground">このページに候補者はいません</p>;
  } else {
    content = (
      <>
        <ul className="space-y-3">
          {data.items.map((candidacy) => (
            <CandidacyRow key={candidacy.id} candidacy={candidacy} options={options} />
          ))}
        </ul>
        <PageNav
          page={data.pagination.page}
          totalPages={data.pagination.total_pages}
          // タブを残したまま、ページだけ変える
          hrefFor={(nextPage) => pageUrl(buildQuery(jobPostingId, nextPage))}
        />
      </>
    );
  }

  // タブ：「すべて」＋自社の募集ごと。押すと URL が変わり、一覧を取り直す（タブを変えたら1ページ目に戻る）
  const tabs = [
    { key: "all", label: "すべて", jobPostingId: null },
    ...(jobPostings?.items ?? []).map((jobPosting) => ({
      key: String(jobPosting.id),
      label: jobPosting.title,
      jobPostingId: String(jobPosting.id),
    })),
  ];

  return (
    <div className="space-y-6">
      <PageTitle>候補者一覧</PageTitle>

      <nav aria-label="募集で絞る" className="flex flex-wrap gap-2">
        {tabs.map((tab) => {
          const selected = tab.jobPostingId === jobPostingId;
          return (
            <Link
              key={tab.key}
              href={pageUrl(buildQuery(tab.jobPostingId, 1))}
              aria-current={selected ? "page" : undefined}
              className={buttonVariants({ variant: selected ? "secondary" : "ghost", size: "sm" })}
            >
              {tab.label}
            </Link>
          );
        })}
      </nav>

      {content}
    </div>
  );
}

// ── 行 ──
// 部品は、画面の部品の中ではなく、このファイルの一番上の段に置く

type CandidacyRowProps = {
  candidacy: CompanyCandidacyRow;
  options: Options;
};

// やりとり1件の行。学生・募集・タグ・始まった日と、「詳細を見る」
function CandidacyRow({ candidacy, options }: CandidacyRowProps) {
  const { student, job_posting: jobPosting } = candidacy;
  // 学年・卒業年度・活動状況。空欄の項目は飛ばす
  const profileParts = [
    labelOf(options.enums.grade, student.grade),
    student.graduation_year === null ? null : `${student.graduation_year}年卒`,
    labelOf(options.enums.activity_status, student.activity_status),
  ].filter((part) => part !== null);
  // 学生詳細を、この募集のタブを選んだ状態で開く（API設計.md の 16-2 C4）
  const detailHref = `/company/students/${student.id}?job_posting_id=${jobPosting.id}`;

  return (
    <li className="space-y-3 rounded-lg border p-4">
      <div className="flex flex-wrap items-center gap-2">
        <ProfileIcon src={student.icon_url} name={student.name} size="sm" />
        <Link href={detailHref} className="font-bold hover:underline">
          {student.name}
        </Link>
        {/* タグは Rails が計算したものを日本語にするだけ（画面側では組み立てない。16-1-9） */}
        <StatusBadge size="sm">{labelOf(options.enums.candidacy_tag, candidacy.tag) ?? candidacy.tag}</StatusBadge>
      </div>

      <div className="space-y-1 text-sm">
        {profileParts.length > 0 && <p className="text-muted-foreground">{profileParts.join(" ・ ")}</p>}
        <p>
          {jobPosting.title}
          <span className="text-muted-foreground"> ・ 始まった日：{formatDate(candidacy.created_at)}</span>
        </p>
      </div>

      <div className="flex flex-wrap gap-2">
        <Link href={detailHref} className={buttonVariants({ variant: "outline", size: "sm" })}>
          詳細を見る
        </Link>
        {/* マッチ以降の行だけ。判定は Rails（after_match）で、状態から組み立てない（16-1-9。PR224） */}
        {candidacy.after_match && (
          <Link
            href={`/company/messages?student_id=${student.id}`}
            className={buttonVariants({ variant: "outline", size: "sm" })}
          >
            メッセージ
          </Link>
        )}
      </div>
    </li>
  );
}
