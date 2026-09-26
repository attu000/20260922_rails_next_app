"use client";

// 学生詳細（C6）の中身。詳しくは design/designs/ページ設計.md の 6-5 C6、API設計.md の 16-3 ㉓㉔㉖。
// 開いたら ㉓ 学生詳細と ⑦ 選択肢を取り、学生の名前、募集タブ、選んだ募集での状態とボタン、学生のプロフィールを並べる。
// 最初に選ぶタブは URL の ?job_posting_id=（候補者一覧から来たときはその募集）。なければ先頭の募集。
// ボタンは Rails が返す available_actions だけに従う。画面側では状態から組み立てない（16-1-9）。
// 次のものは、それを作る順で足す
//   - 「この学生とのメッセージ」（has_message_thread を使う）：行き先のメッセージ管理を作る順7（PR213）
//   - 送信後の「この学生に似た学生」のポップアップ：順14
//   - 比較の表示と応募理由の♥印：順10、見送る・見送りを取り消す・合格・不合格：順11
//   - 最終活動の目安：【仕上げ】

import { useState } from "react";
import { cn } from "cn";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useRedirectIfUnauthorized } from "@/components/member-only";
import { PageTitle } from "@/components/page-title";
import { ProfileIcon } from "@/components/profile-icon";
import { ScoutDialog } from "@/components/scout-dialog";
import { StatusBadge } from "@/components/status-badge";
import { StudentProfileView } from "@/components/student-profile-view";
import { Button, buttonVariants } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Separator } from "@/components/ui/separator";
import { ApiError, apiFetch, useApi } from "@/lib/api";
import type { CompanyJobPostingState, CompanyStudentDetail as Detail } from "@/lib/company-students";
import { formatDate } from "@/lib/format";
import { labelOf, type Options, useOptions } from "@/lib/options";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

export function CompanyStudentDetail({ studentId }: { studentId: string }) {
  const searchParams = useSearchParams();
  const { options, failed: optionsFailed } = useOptions();
  // URL の [id] の部分は利用者が書き換えられるので、符号化してから入れる。
  // mutate：覚えている中身を書き換える・取り直す関数（マッチ・スカウトのあとに使う）
  const { data, error, mutate } = useApi<Detail>(`/api/company/students/${encodeURIComponent(studentId)}`);
  // マッチ・スカウトができなかったときの一言（「この操作は今はできません…」など）。取り直して状態が変わっても出したままにする
  const [message, setMessage] = useState<string | null>(null);

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  // ㉓ が取れなかった（存在しない番号なら「見つかりません」）。401 は共通の枠がログイン画面へ移すので、読み込み中のままにする
  if (!data && error && error.status !== 401) {
    return <p className="text-sm text-destructive">{error.message}</p>;
  }

  if (!options || !data) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  // 選んでいるタブ。URL の番号が自社の募集になければ、先頭の募集
  const requestedId = Number(searchParams.get("job_posting_id"));
  const selected =
    data.job_postings.find((jobPosting) => jobPosting.id === requestedId) ?? data.job_postings[0] ?? null;

  // マッチ・スカウトができたら、返ってきた「その募集の状態」で、そのタブの中身だけを書き換える（取り直しはしない）
  function handleStateChanged(state: CompanyJobPostingState) {
    if (!data) return;
    setMessage(null);
    void mutate(
      {
        ...data,
        job_postings: data.job_postings.map((jobPosting) => (jobPosting.id === state.id ? state : jobPosting)),
      },
      { revalidate: false },
    );
  }

  // マッチ・スカウトができなかったら（409 など）、一言を出し、取り直して最新の状態にする
  function handleFailed(failedMessage: string) {
    setMessage(failedMessage);
    void mutate();
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <ProfileIcon src={data.student.icon_url} name={data.student.name} size="lg" />
        <PageTitle>{data.student.name}</PageTitle>
      </div>

      {/* 募集タブと、その中身。タブは枠の外に並べ、選んだタブだけを下の大きな枠とつなげて見せる（PR217）。
          タブの中身は、その募集での状態・ボタンと、学生のプロフィール（ページ設計.md の 6-5 C6。順10 で比較もここに入る） */}
      <div>
        {selected !== null && (
          // -mb-px：タブを1ピクセル下げて、枠の上の線に重ねる。選んだタブは下の線を背景色にして、枠とつながって見せる
          <nav aria-label="募集" className="-mb-px flex flex-wrap gap-1">
            {data.job_postings.map((jobPosting) => {
              const isSelected = jobPosting.id === selected.id;
              return (
                <Link
                  key={jobPosting.id}
                  href={`/company/students/${encodeURIComponent(studentId)}?job_posting_id=${jobPosting.id}`}
                  // タブの切り替えは、ブラウザの「戻る」の履歴に積まない
                  replace
                  scroll={false}
                  aria-current={isSelected ? "page" : undefined}
                  className={cn(
                    "rounded-t-lg border px-3 py-1.5 text-sm",
                    isSelected
                      ? "border-b-background bg-background font-bold"
                      : "border-transparent text-muted-foreground hover:text-foreground",
                  )}
                >
                  {jobPosting.title}
                </Link>
              );
            })}
          </nav>
        )}

        {/* 大きな枠：選んだ募集での状態・ボタンと、学生のプロフィールを囲む。
            先頭のタブが選ばれているときに角が浮かないよう、タブがあれば左上の角は丸めない */}
        <section className={cn("space-y-6 rounded-lg border p-4", selected !== null && "rounded-tl-none")}>
          <div className="space-y-3">
            {selected === null ? (
              <p className="text-sm text-muted-foreground">募集がまだありません</p>
            ) : (
              <JobPostingPanel
                // タブを変えたら、確認のポップアップなどの状態を持ち越さない
                key={selected.id}
                state={selected}
                studentId={studentId}
                studentName={data.student.name}
                options={options}
                onStateChanged={handleStateChanged}
                onFailed={handleFailed}
              />
            )}
            {message && <p className="text-sm text-destructive">{message}</p>}
          </div>

          <Separator />

          <StudentProfileView student={data.student} options={options} />
        </section>
      </div>
    </div>
  );
}

// ── 選んだ募集のタブの中身 ──
// 部品は、画面の部品の中ではなく、このファイルの一番上の段に置く

type JobPostingPanelProps = {
  state: CompanyJobPostingState;
  // 学生の番号（URL の番号）と名前
  studentId: string;
  studentName: string;
  options: Options;
  // マッチ・スカウトができたとき。返ってきた「その募集の状態」を渡す
  onStateChanged: (state: CompanyJobPostingState) => void;
  // マッチ・スカウトができなかったとき。message は画面に出す一言
  onFailed: (message: string) => void;
};

// 募集の状態、その学生とのやりとりの状態、押せるボタン
function JobPostingPanel({ state, studentId, studentName, options, onStateChanged, onFailed }: JobPostingPanelProps) {
  const { candidacy } = state;

  return (
    <div className="space-y-3">
      <p className="text-sm">
        <span className="font-bold">{state.title}</span>
        <span className="text-muted-foreground">
          {" ・ "}
          {labelOf(options.enums.job_posting_status, state.status)}
        </span>
      </p>

      {candidacy === null ? (
        <p className="text-sm text-muted-foreground">この募集とのやりとりはありません</p>
      ) : (
        <div className="flex flex-wrap items-center gap-2 text-sm">
          {/* タグは Rails が計算したものを日本語にするだけ（画面側では組み立てない。16-1-9） */}
          <StatusBadge>{labelOf(options.enums.candidacy_tag, candidacy.tag) ?? candidacy.tag}</StatusBadge>
          {candidacy.matched_at && (
            <span className="text-muted-foreground">マッチした日：{formatDate(candidacy.matched_at)}</span>
          )}
        </div>
      )}

      {/* ボタンは available_actions にあるものだけ。順11 で見送る・合格・不合格などが増える */}
      {state.available_actions.includes("scout") && (
        <ScoutDialog
          jobPostingId={state.id}
          jobPostingTitle={state.title}
          studentId={studentId}
          studentName={studentName}
          onScouted={onStateChanged}
          onFailed={onFailed}
        />
      )}
      {candidacy !== null && state.available_actions.includes("match") && (
        <MatchDialog
          candidacyId={candidacy.id}
          studentName={studentName}
          jobPostingTitle={state.title}
          onMatched={onStateChanged}
          onFailed={onFailed}
        />
      )}
    </div>
  );
}

type MatchDialogProps = {
  candidacyId: number;
  studentName: string;
  jobPostingTitle: string;
  onMatched: (state: CompanyJobPostingState) => void;
  onFailed: (message: string) => void;
};

// 「マッチする」のボタンと、確認のポップアップ（PR210）。
// マッチは取り消せない（マッチ以降は未マッチ・見送りに戻せない。権限_バリデーション.md の 17-2-1）ので、押し間違いを防ぐ
function MatchDialog({ candidacyId, studentName, jobPostingTitle, onMatched, onFailed }: MatchDialogProps) {
  const redirectIfUnauthorized = useRedirectIfUnauthorized();
  const [open, setOpen] = useState(false);
  // 送っている途中か。2回押しても、1回だけ送る。ボタンは押せなくしない（権限_バリデーション.md の 17-3-2）
  const [submitting, setSubmitting] = useState(false);

  async function handleConfirm() {
    if (submitting) return;
    setSubmitting(true);
    try {
      // ㉖ マッチする。返事は、その募集の状態（形D）
      const state = await apiFetch<CompanyJobPostingState>(`/api/company/candidacies/${candidacyId}/match`, {
        method: "POST",
      });
      setOpen(false);
      onMatched(state);
    } catch (error) {
      if (redirectIfUnauthorized(error)) return;
      // 今の状態ではできない（409。別のタブでマッチ済み、募集が終了した、など）ほかは、閉じて一言を出し、取り直す
      setOpen(false);
      onFailed(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger className={buttonVariants()}>マッチする</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{studentName}さんとマッチしますか？</DialogTitle>
          <DialogDescription>
            募集「{jobPostingTitle}」への応募にマッチします。マッチは取り消せません。
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose render={<Button type="button" variant="outline" />}>キャンセル</DialogClose>
          <Button type="button" onClick={handleConfirm}>
            {submitting ? "送信中…" : "マッチする"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
