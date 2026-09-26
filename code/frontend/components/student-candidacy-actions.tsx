"use client";

// 募集詳細（S6）の、自分の状態の表示と「応募する」「マッチする」
// （design/designs/ページ設計.md の 6-6 S6、API設計.md の 16-3 ⑲㉛㉜）。
// 状態（my_status）は Rails が計算して返したものをそのまま使い、画面側では組み立てない（16-1-9）。
// 守りは Rails にある（応募済み・募集終了・応募由来へのマッチなら 409、理由が0個なら 422）。
// 画面側のボタンの出し分けと確かめは、見た目と送る手間を省くためだけ。
// マッチ理由は、応募理由と同じ項目・同じ文言で選ぶ（PR218）。
// 応募完了のポップアップ（この募集に似た募集）は順14 で足す

import { useState, type FormEvent, type ReactNode } from "react";
import { toFieldErrorItems } from "@/components/form-fields";
import { useRedirectIfUnauthorized } from "@/components/member-only";
import { StatusBadge } from "@/components/status-badge";
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
  // 応募・マッチができたとき。返ってきた状態で、画面の募集詳細を書き換える（読み直しはしない）
  onStatusChanged: (status: MyCandidacyStatus) => void;
  // 応募・マッチができなかったとき（409 など）。募集詳細を取り直して、最新の状態にする
  onFailed: () => void;
};

export function StudentCandidacyActions({
  jobPostingId,
  isOpen,
  status,
  reasonOptions,
  statusOptions,
  onStatusChanged,
  onFailed,
}: StudentCandidacyActionsProps) {
  // 応募・マッチができなかったときの一言（「この操作は今はできません…」など）。取り直して状態が変わっても出したままにする
  const [message, setMessage] = useState<string | null>(null);

  // 理由を選ぶポップアップに共通で渡すもの
  const dialogProps = {
    reasonOptions,
    onDone: (result: MyCandidacyStatus) => {
      setMessage(null);
      onStatusChanged(result);
    },
    onFailed: (failedMessage: string) => {
      setMessage(failedMessage);
      onFailed();
    },
  };

  let content: ReactNode;
  if (status.my_status === "none") {
    // 関係がない。掲載中なら「応募する」、掲載中でなければ応募できないので何も出さない
    content = isOpen ? (
      <ReasonsDialog
        {...dialogProps}
        triggerLabel="応募する"
        // ㉛ 応募する。返事は自分の状態（形E）
        submit={(reasons) =>
          apiFetch<MyCandidacyStatus>("/api/student/candidacies", {
            method: "POST",
            body: { job_posting_id: jobPostingId, reasons },
          })
        }
      />
    ) : null;
  } else {
    // 応募済み・スカウトあり・マッチ済み。企業側で見送り・合格・不合格になっていても、Rails がこの3つのどれかで返す
    const badge = <StatusBadge>{labelOf(statusOptions, status.my_status) ?? status.my_status}</StatusBadge>;
    const candidacyId = status.my_candidacy_id;
    // スカウトありで掲載中なら、札に「マッチする」を添える（企業に見送られていても、学生には見せず、応じられる）
    content =
      status.my_status === "scouted" && isOpen && candidacyId !== null ? (
        <div className="flex flex-wrap items-center gap-2">
          {badge}
          <ReasonsDialog
            {...dialogProps}
            triggerLabel="マッチする"
            // ㉜ スカウトにマッチする。返事は自分の状態（形E）
            submit={(reasons) =>
              apiFetch<MyCandidacyStatus>(`/api/student/candidacies/${candidacyId}/match`, {
                method: "POST",
                body: { reasons },
              })
            }
          />
        </div>
      ) : (
        badge
      );
  }

  if (content === null && message === null) return null;

  return (
    <div className="space-y-2">
      {content}
      {message && <p className="text-sm text-destructive">{message}</p>}
    </div>
  );
}

type ReasonsDialogProps = {
  // ボタンとポップアップの題名の文字（「応募する」／「マッチする」）
  triggerLabel: string;
  reasonOptions: EnumOption[];
  // 選んだ理由を送る処理。応募とマッチで送り先が違うので、使う側が渡す
  submit: (reasons: string[]) => Promise<MyCandidacyStatus>;
  onDone: (status: MyCandidacyStatus) => void;
  // 入力の誤り（422）以外で送れなかったとき。message は画面に出す一言
  onFailed: (message: string) => void;
};

// 「応募する」「マッチする」のボタンと、応募理由を選ぶポップアップ（12項目から複数、最低1つ。その他決め事.md の 5-1）。
// マッチ理由は応募理由と同じ項目なので、説明・欄の見出し・エラーの文言も応募と同じにする（PR218）。
// 学生のメッセージ管理の「マッチする」（components/message-center.tsx。PR222）でも使う
export function ReasonsDialog({ triggerLabel, reasonOptions, submit, onDone, onFailed }: ReasonsDialogProps) {
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
      // ② 送る（応募なら ㉛、マッチなら ㉜）。返事は自分の状態（形E）
      const result = await submit(selectedReasons);
      setOpen(false);
      onDone(result);
    } catch (error) {
      if (redirectIfUnauthorized(error)) return;
      // ③ 入力の誤り（422）なら、開いたまま、応募理由の欄の下に出す
      if (error instanceof ApiError && error.status === 422 && error.errors) {
        setErrors(error.errors.reasons ?? [error.message]);
        return;
      }
      // 今の状態ではできない（409。別のタブで応募・マッチ済み、募集が終了した、など）ほかは、閉じて一言を出し、取り直す
      setOpen(false);
      onFailed(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger className={buttonVariants()}>{triggerLabel}</DialogTrigger>
      {/* 中身が長ければ、題名と下のボタンは動かさず、中身だけを縦に動かせるようにする */}
      <DialogContent className="max-h-[85vh] grid-rows-[minmax(0,1fr)] sm:max-w-lg">
        <form onSubmit={handleSubmit} className="grid min-h-0 grid-rows-[auto_minmax(0,1fr)_auto] gap-4">
          <DialogHeader>
            <DialogTitle>{triggerLabel}</DialogTitle>
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
            <Button type="submit">{submitting ? "送信中…" : triggerLabel}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
