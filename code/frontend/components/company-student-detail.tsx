"use client";

// 学生詳細（C6）の中身。詳しくは design/designs/ページ設計.md の 6-5 C6、API設計.md の 16-3 ㉓㉔㉖〜㉚。
// 開いたら ㉓ 学生詳細と ⑦ 選択肢を取り、学生の名前、募集の選択欄、選んだ募集での状態とボタン、
// 応募理由・マッチ理由と募集との比較（順10。components/company-student-comparison.tsx）、学生のプロフィールを並べる。
// 最初に選ぶ募集は URL の ?job_posting_id=（候補者一覧から来たときはその募集）。なければ先頭の募集。
// 募集名は長く、横に並べると折り返すので、タブではなく選択欄で選ぶ（PR267）。
// ボタンは Rails が返す available_actions だけに従う。画面側では状態から組み立てない（16-1-9）。
// やりとりを変えるボタン（マッチする・見送る・見送りを取り消す・合格・不合格）は、すべて確認のポップアップを挟む（順11）。
// 「この学生とのメッセージ」は、募集の選択欄の外（名前の横）に、Rails の has_message_thread が true のときだけ出す（PR213）。
// スカウトを送ったら、「この学生に似た学生」のポップアップを開く（components/similar-students-dialog.tsx。順14）。
// 最終活動の目安は、名前の下に出す。一度もログインしていない学生（Rails が null を返す）には出さない（PR335）。
// 修了したプチ職業体験と自己分析のポップアップは、いちばん下（プロフィールの「稼働条件」の下。components/company-self-analyses.tsx。順19）

import { useState } from "react";
import { cn } from "cn";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { CompletedJobTrials } from "@/components/company-self-analyses";
import { CandidacyReasons, JobPostingComparison } from "@/components/company-student-comparison";
import { useRedirectIfUnauthorized } from "@/components/member-only";
import { PageTitle } from "@/components/page-title";
import { ProfileIcon } from "@/components/profile-icon";
import { ScoutDialog } from "@/components/scout-dialog";
import { SimilarStudentsDialog } from "@/components/similar-students-dialog";
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
import { NativeSelect, NativeSelectOption } from "@/components/ui/native-select";
import { Separator } from "@/components/ui/separator";
import { ApiError, apiFetch, useApi } from "@/lib/api";
import type { CompanyJobPostingState, CompanyStudentDetail as Detail } from "@/lib/company-students";
import { formatDate } from "@/lib/format";
import { labelOf, type Options, useOptions } from "@/lib/options";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

export function CompanyStudentDetail({ studentId }: { studentId: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { options, failed: optionsFailed } = useOptions();
  // URL の [id] の部分は利用者が書き換えられるので、符号化してから入れる。
  // mutate：覚えている中身を書き換える・取り直す関数（マッチ・スカウトのあとに使う）
  const { data, error, mutate } = useApi<Detail>(`/api/company/students/${encodeURIComponent(studentId)}`);
  // 操作ができなかったときの一言（「この操作は今はできません…」など）。取り直して状態が変わっても出したままにする
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

  // 選んでいる募集。URL の番号が自社の募集になければ、先頭の募集
  const requestedId = Number(searchParams.get("job_posting_id"));
  const selected =
    data.job_postings.find((jobPosting) => jobPosting.id === requestedId) ?? data.job_postings[0] ?? null;

  // 募集を選び直したら、URL の ?job_posting_id= を書き換える。ブラウザの「戻る」の履歴には積まない（タブだったときと同じ）
  function selectJobPosting(jobPostingId: string) {
    router.replace(`/company/students/${encodeURIComponent(studentId)}?job_posting_id=${encodeURIComponent(jobPostingId)}`, {
      scroll: false,
    });
  }

  // スカウト・マッチ・見送りなどができたら、返ってきた「その募集の状態」で、選んだ募集の中身だけを書き換える（取り直しはしない）。
  // 返事（形D）には比較が入っていないので、丸ごと置き換えず、元の中身に重ねる（比較はこれらの操作では変わらない）
  function handleStateChanged(state: CompanyJobPostingState) {
    if (!data) return;
    setMessage(null);
    void mutate(
      {
        ...data,
        job_postings: data.job_postings.map((jobPosting) =>
          jobPosting.id === state.id ? { ...jobPosting, ...state } : jobPosting,
        ),
      },
      { revalidate: false },
    );
  }

  // スカウト・マッチ・見送りなどができなかったら（409 など）、一言を出し、取り直して最新の状態にする
  function handleFailed(failedMessage: string) {
    setMessage(failedMessage);
    void mutate();
  }

  // 最終活動の目安（「7日以内」など）。Rails が返した名前を ⑦ の表示名にするだけ。null なら出さない（PR335）
  const lastActiveLabel = labelOf(options.enums.last_active_range, data.student.last_active_range);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-3">
        <ProfileIcon src={data.student.icon_url} name={data.student.name} size="lg" />
        <div className="space-y-1">
          <PageTitle>{data.student.name}</PageTitle>
          {lastActiveLabel !== null && (
            <p className="text-sm text-muted-foreground">最終活動：{lastActiveLabel}</p>
          )}
        </div>
        {/* メッセージは募集ごとではなく相手ごとなので、募集の選択欄の外に置く。
            スレッドがあれば出す（送れるかどうかは、行き先のメッセージ管理が決める。権限_バリデーション.md の 17-2-3） */}
        {data.has_message_thread && (
          <Link
            href={`/company/messages?student_id=${encodeURIComponent(studentId)}`}
            className={cn(buttonVariants({ variant: "outline", size: "sm" }), "ml-auto")}
          >
            この学生とのメッセージ
          </Link>
        )}
      </div>

      {/* 募集の選択欄と、選んだ募集の中身（ページ設計.md の 6-5 C6）。
          中身は、その募集での状態・ボタン、応募理由、募集との比較、学生のプロフィール */}
      <div className="space-y-3">
        {selected !== null && (
          // 学生検索の「募集を選ぶ」と同じ、ブラウザ標準の選択欄（PR267）。スマホでは標準の選択の画面になり、長い募集名も読める。
          // 非公開・終了の募集は、名前の後ろに状態を付ける（ボタンが出ない理由がわかるように。掲載中は付けない。PR268）
          <div className="flex flex-wrap items-center gap-2">
            <label htmlFor="student-detail-job-posting" className="text-sm">
              募集
            </label>
            <NativeSelect
              id="student-detail-job-posting"
              className="max-w-full"
              value={String(selected.id)}
              onChange={(event) => selectJobPosting(event.target.value)}
            >
              {data.job_postings.map((jobPosting) => (
                <NativeSelectOption key={jobPosting.id} value={String(jobPosting.id)}>
                  {jobPosting.status === "published"
                    ? jobPosting.title
                    : `${jobPosting.title}（${labelOf(options.enums.job_posting_status, jobPosting.status) ?? jobPosting.status}）`}
                </NativeSelectOption>
              ))}
            </NativeSelect>
          </div>
        )}

        {/* 大きな枠：選んだ募集での状態・ボタンと、学生のプロフィールを囲む */}
        <section className="space-y-6 rounded-lg border p-4">
          <div className="space-y-3">
            {selected === null ? (
              <p className="text-sm text-muted-foreground">募集がまだありません</p>
            ) : (
              <JobPostingPanel
                // 募集を選び直したら、確認のポップアップなどの状態を持ち越さない
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
            {/* 応募理由・マッチ理由は、あるときだけ（応募したとき、スカウトに学生がマッチしたときに付く。PR255） */}
            {selected?.candidacy && selected.candidacy.reasons.length > 0 && (
              <CandidacyReasons
                reasons={selected.candidacy.reasons}
                origin={selected.candidacy.origin}
                reasonOptions={options.enums.candidacy_reason}
              />
            )}
          </div>

          {/* 募集との比較（左に学生、右に募集。PR256）。募集を選び直すと、ここが変わる */}
          {selected !== null && (
            <>
              <Separator />
              <JobPostingComparison student={data.student} comparison={selected.comparison} options={options} />
            </>
          )}

          <Separator />

          <StudentProfileView student={data.student} options={options} />

          {/* 修了したプチ職業体験（順19）。いちばん下、プロフィールの「稼働条件」の下に置く。1つもなければ出さない */}
          <CompletedJobTrials selfAnalyses={data.self_analyses} studentName={data.student.name} options={options} />
        </section>
      </div>
    </div>
  );
}

// ── 選んだ募集の中身 ──
// 部品は、画面の部品の中ではなく、このファイルの一番上の段に置く

type JobPostingPanelProps = {
  state: CompanyJobPostingState;
  // 学生の番号（URL の番号）と名前
  studentId: string;
  studentName: string;
  options: Options;
  // 操作ができたとき。返ってきた「その募集の状態」を渡す
  onStateChanged: (state: CompanyJobPostingState) => void;
  // 操作ができなかったとき。message は画面に出す一言
  onFailed: (message: string) => void;
};

// その学生とのやりとりの状態と、押せるボタン。
// 募集名と募集の状態は、すぐ上の選択欄に出ているので、ここでは繰り返さない（PR268）
function JobPostingPanel({ state, studentId, studentName, options, onStateChanged, onFailed }: JobPostingPanelProps) {
  // スカウト送信後の「この学生に似た学生」のポップアップが開いているか（順14）
  const [similarOpen, setSimilarOpen] = useState(false);
  const { candidacy } = state;
  // やりとりを変えるボタンのうち、Rails が「今押せる」と返したもの（やりとりがあるときだけ）
  const candidacyActions =
    candidacy === null ? [] : CANDIDACY_ACTIONS.filter(({ action }) => state.available_actions.includes(action));
  const canScout = state.available_actions.includes("scout");

  return (
    <div className="space-y-3">
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

      {/* ボタンは available_actions にあるものだけ。並びは Rails と同じ */}
      {(canScout || candidacyActions.length > 0) && (
        <div className="flex flex-wrap gap-2">
          {canScout && (
            <ScoutDialog
              jobPostingId={state.id}
              jobPostingTitle={state.title}
              studentId={studentId}
              studentName={studentName}
              // 送れたら、表示を「スカウト済み」に書き換えてから、似た学生のポップアップを開く
              onScouted={(scoutedState) => {
                onStateChanged(scoutedState);
                setSimilarOpen(true);
              }}
              onFailed={onFailed}
            />
          )}
          {candidacy !== null &&
            candidacyActions.map((candidacyAction) => (
              <CandidacyActionDialog
                key={candidacyAction.action}
                candidacyAction={candidacyAction}
                candidacyId={candidacy.id}
                studentName={studentName}
                jobPostingTitle={state.title}
                onDone={onStateChanged}
                onFailed={onFailed}
              />
            ))}
        </div>
      )}

      {/* スカウトのポップアップの外に置く。送ったあとは「スカウトをする」のボタンごと消えるため */}
      <SimilarStudentsDialog
        open={similarOpen}
        onOpenChange={setSimilarOpen}
        studentId={studentId}
        jobPostingId={state.id}
        options={options}
      />
    </div>
  );
}

// やりとりを変えるボタンの中身。
// action はボタンの名前（available_actions の値）で、送り先の URL の最後の部分と同じ（/api/company/candidacies/:id/decline など）
type CandidacyAction = {
  action: "match" | "decline" | "undo_decline" | "pass" | "fail";
  // ボタンと、ポップアップの「する」ボタンの文字
  label: string;
  // ポップアップの見出しと説明
  title: (studentName: string) => string;
  description: (jobPostingTitle: string) => string;
  // 塗りつぶしのボタンにするか（「マッチする」だけ。ほかは枠線だけ）
  primary: boolean;
};

// 並びは Rails の available_actions と同じ（match、decline、undo_decline、pass、fail）。
// 見送り・合格・不合格は学生に見せない（その他決め事.md の 5-1）ので、そのことを説明に添える
const CANDIDACY_ACTIONS: CandidacyAction[] = [
  {
    action: "match",
    label: "マッチする",
    title: (studentName) => `${studentName}さんとマッチしますか？`,
    // マッチは取り消せない（マッチ以降は未マッチ・見送りに戻せない。権限_バリデーション.md の 17-2-1。PR210）
    description: (jobPostingTitle) => `募集「${jobPostingTitle}」への応募にマッチします。マッチは取り消せません。`,
    primary: true,
  },
  {
    action: "decline",
    label: "見送る",
    title: (studentName) => `${studentName}さんを見送りますか？`,
    description: (jobPostingTitle) =>
      `募集「${jobPostingTitle}」でのやりとりを見送りにします。学生には知らされません。あとで取り消せます。`,
    primary: false,
  },
  {
    action: "undo_decline",
    label: "見送りを取り消す",
    title: (studentName) => `${studentName}さんの見送りを取り消しますか？`,
    description: (jobPostingTitle) => `募集「${jobPostingTitle}」でのやりとりを、見送る前の状態に戻します。`,
    primary: false,
  },
  {
    action: "pass",
    label: "合格として保存",
    title: (studentName) => `${studentName}さんを合格として保存しますか？`,
    description: (jobPostingTitle) => `募集「${jobPostingTitle}」の結果を合格にします。学生には知らされません。`,
    primary: false,
  },
  {
    action: "fail",
    label: "不合格として保存",
    title: (studentName) => `${studentName}さんを不合格として保存しますか？`,
    description: (jobPostingTitle) => `募集「${jobPostingTitle}」の結果を不合格にします。学生には知らされません。`,
    primary: false,
  },
];

type CandidacyActionDialogProps = {
  candidacyAction: CandidacyAction;
  candidacyId: number;
  studentName: string;
  jobPostingTitle: string;
  onDone: (state: CompanyJobPostingState) => void;
  onFailed: (message: string) => void;
};

// やりとりを変えるボタンと、確認のポップアップ（㉖〜㉚）。
// マッチは取り消せないので押し間違いを防ぐため（PR210）、ほかの4つも念のため、すべて確認を挟む（順11）
function CandidacyActionDialog({
  candidacyAction,
  candidacyId,
  studentName,
  jobPostingTitle,
  onDone,
  onFailed,
}: CandidacyActionDialogProps) {
  const redirectIfUnauthorized = useRedirectIfUnauthorized();
  const [open, setOpen] = useState(false);
  // 送っている途中か。2回押しても、1回だけ送る。ボタンは押せなくしない（権限_バリデーション.md の 17-3-2）
  const [submitting, setSubmitting] = useState(false);
  const { action, label, title, description, primary } = candidacyAction;

  async function handleConfirm() {
    if (submitting) return;
    setSubmitting(true);
    try {
      // 返事は、操作したあとの、その募集の状態（形D）
      const state = await apiFetch<CompanyJobPostingState>(`/api/company/candidacies/${candidacyId}/${action}`, {
        method: "POST",
      });
      setOpen(false);
      onDone(state);
    } catch (error) {
      if (redirectIfUnauthorized(error)) return;
      // 今の状態ではできない（409。別のタブで操作済み、募集が終了した、など）ほかは、閉じて一言を出し、取り直す
      setOpen(false);
      onFailed(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger className={buttonVariants({ variant: primary ? "default" : "outline" })}>{label}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title(studentName)}</DialogTitle>
          <DialogDescription>{description(jobPostingTitle)}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose render={<Button type="button" variant="outline" />}>キャンセル</DialogClose>
          <Button type="button" onClick={handleConfirm}>
            {submitting ? "送信中…" : label}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
