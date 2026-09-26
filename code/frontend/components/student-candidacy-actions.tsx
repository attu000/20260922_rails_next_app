"use client";

// 募集詳細（S6）の、自分の状態の表示と「応募する」（design/designs/ページ設計.md の 6-6 S6、API設計.md の 16-3 ⑲㉛）。
// 状態（my_status）は Rails が計算して返したものをそのまま使い、画面側では組み立てない（16-1-9）。
// 守りは Rails にある（応募済み・募集終了なら 409、応募理由が0個なら 422）。画面側の確かめは、送る手間を省くためだけ。
// 次のものは、それを作る順で足す
//   - スカウトありのときの「マッチする」（マッチ理由を選ぶ）：順6
//   - 応募完了のポップアップ（この募集に似た募集）：順14

import { useState, type FormEvent, type ReactNode } from "react";
import { toFieldErrorItems } from "@/components/form-fields";
import { useRedirectIfUnauthorized } from "@/components/member-only";
import { Button, buttonVariants } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
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
import { Field, FieldError, FieldLabel, FieldLegend, FieldSet } from "@/components/ui/field";
import { ApiError, apiFetch } from "@/lib/api";
import { labelOf, type EnumOption } from "@/lib/options";
import type { MyCandidacyStatus } from "@/lib/student-job-postings";

// 応募理由のうち、まだ募集詳細に出ていない4項目（業界・事業形態・工程・カルチャー）。
// 見えていない項目を理由に選べると迷うので、ポップアップから外す。Rails は12個すべてを受け付ける。
// 順9 でこれらを募集詳細に出すときに、この定数ごと消す（PR203）
const REASONS_SHOWN_FROM_ORDER9 = ["industry", "business_type", "work_process", "culture"];

// 応募理由を1つも選ばずに押したときの文言。Rails の 422 と同じ（権限_バリデーション.md の 17-3-6）
const REASONS_REQUIRED_MESSAGE = "応募理由を入力してください";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

type StudentCandidacyActionsProps = {
  jobPostingId: number;
  // 掲載中か。false なら応募できない（タイトルの横に「募集終了」が出ている）
  isOpen: boolean;
  status: MyCandidacyStatus;
  // ⑦ の enums.candidacy_reason と enums.my_status
  reasonOptions: EnumOption[];
  statusOptions: EnumOption[];
  // 応募できたとき。返ってきた状態で、画面の募集詳細を書き換える（読み直しはしない）
  onApplied: (status: MyCandidacyStatus) => void;
  // 応募できなかったとき（409 など）。募集詳細を取り直して、最新の状態にする
  onFailed: () => void;
};

export function StudentCandidacyActions({
  jobPostingId,
  isOpen,
  status,
  reasonOptions,
  statusOptions,
  onApplied,
  onFailed,
}: StudentCandidacyActionsProps) {
  // 応募できなかったときの一言（「この操作は今はできません…」など）。取り直して状態が変わっても出したままにする
  const [message, setMessage] = useState<string | null>(null);

  let content: ReactNode;
  if (status.my_status !== "none") {
    // 応募済み・スカウトあり・マッチ済み。企業側で見送り・合格・不合格になっていても、Rails がこの3つのどれかで返す
    content = (
      <span className="inline-flex rounded-md bg-secondary px-2 py-1 text-sm font-medium">
        {labelOf(statusOptions, status.my_status)}
      </span>
    );
  } else if (isOpen) {
    content = (
      <ApplyDialog
        jobPostingId={jobPostingId}
        reasonOptions={reasonOptions}
        onApplied={(result) => {
          setMessage(null);
          onApplied(result);
        }}
        onFailed={(failedMessage) => {
          setMessage(failedMessage);
          onFailed();
        }}
      />
    );
  } else {
    // 関係がなく、掲載中でもない。応募できないので何も出さない
    content = null;
  }

  if (content === null && message === null) return null;

  return (
    <div className="space-y-2">
      {content}
      {message && <p className="text-sm text-destructive">{message}</p>}
    </div>
  );
}

type ApplyDialogProps = {
  jobPostingId: number;
  reasonOptions: EnumOption[];
  onApplied: (status: MyCandidacyStatus) => void;
  // 入力の誤り（422）以外で応募できなかったとき。message は画面に出す一言
  onFailed: (message: string) => void;
};

// 「応募する」のボタンと、応募理由を選ぶポップアップ（12項目から複数、最低1つ。その他決め事.md の 5-1）
function ApplyDialog({ jobPostingId, reasonOptions, onApplied, onFailed }: ApplyDialogProps) {
  const redirectIfUnauthorized = useRedirectIfUnauthorized();
  const [open, setOpen] = useState(false);
  // 選んだ応募理由の名前（"business" など）
  const [selectedReasons, setSelectedReasons] = useState<string[]>([]);
  // 応募理由の欄の下に出すエラー
  const [errors, setErrors] = useState<string[] | undefined>(undefined);
  // 送っている途中か。2回押しても、1回だけ送る。ボタンは押せなくしない（権限_バリデーション.md の 17-3-2）
  const [submitting, setSubmitting] = useState(false);

  // 画面に出す順（⑦ の並び）のまま、まだ募集詳細に出ていない項目だけを外す
  const shownReasons = reasonOptions.filter((option) => !REASONS_SHOWN_FROM_ORDER9.includes(option.value));

  // 開くたびに、選んだものとエラーを空にする
  function handleOpenChange(nextOpen: boolean) {
    if (nextOpen) {
      setSelectedReasons([]);
      setErrors(undefined);
    }
    setOpen(nextOpen);
  }

  function toggle(value: string, checked: boolean) {
    setSelectedReasons((current) => (checked ? [...current, value] : current.filter((reason) => reason !== value)));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で送る
    event.preventDefault();
    if (submitting) return;

    // ① 1つも選んでいなければ、送らずにエラーを出す
    if (selectedReasons.length === 0) {
      setErrors([REASONS_REQUIRED_MESSAGE]);
      return;
    }
    setErrors(undefined);
    setSubmitting(true);

    try {
      // ② 応募する（㉛）。返事は自分の状態（形E）
      const result = await apiFetch<MyCandidacyStatus>("/api/student/candidacies", {
        method: "POST",
        body: { job_posting_id: jobPostingId, reasons: selectedReasons },
      });
      setOpen(false);
      onApplied(result);
    } catch (error) {
      if (redirectIfUnauthorized(error)) return;
      // ③ 入力の誤り（422）なら、開いたまま、応募理由の欄の下に出す
      if (error instanceof ApiError && error.status === 422 && error.errors) {
        setErrors(error.errors.reasons ?? [error.message]);
        return;
      }
      // 今の状態ではできない（409。別のタブで応募済み、募集が終了した、など）ほかは、閉じて一言を出し、取り直す
      setOpen(false);
      onFailed(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger className={buttonVariants()}>応募する</DialogTrigger>
      {/* 中身が長ければ、題名と下のボタンは動かさず、中身だけを縦に動かせるようにする */}
      <DialogContent className="max-h-[85vh] grid-rows-[minmax(0,1fr)] sm:max-w-lg">
        <form onSubmit={handleSubmit} className="grid min-h-0 grid-rows-[auto_minmax(0,1fr)_auto] gap-4">
          <DialogHeader>
            <DialogTitle>応募する</DialogTitle>
            <DialogDescription>応募理由を選んでください（複数選べます）</DialogDescription>
          </DialogHeader>
          <div className="-mx-1 overflow-y-auto px-1">
            <FieldSet>
              <FieldLegend variant="label">応募理由</FieldLegend>
              <div className="grid gap-2 sm:grid-cols-2">
                {shownReasons.map((option) => {
                  const id = `reason-${option.value}`;
                  return (
                    <Field key={option.value} orientation="horizontal">
                      <Checkbox
                        id={id}
                        checked={selectedReasons.includes(option.value)}
                        onCheckedChange={(checked) => toggle(option.value, checked)}
                        aria-invalid={errors ? true : undefined}
                      />
                      <FieldLabel htmlFor={id} className="font-normal">
                        {option.label}
                      </FieldLabel>
                    </Field>
                  );
                })}
              </div>
              <FieldError errors={toFieldErrorItems(errors)} />
            </FieldSet>
          </div>
          <DialogFooter>
            <DialogClose render={<Button type="button" variant="outline" />}>キャンセル</DialogClose>
            <Button type="submit">{submitting ? "送信中…" : "応募する"}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
