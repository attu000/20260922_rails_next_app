"use client";

// 学生詳細（C6）の「スカウトをする」のボタンと、スカウト文を入力するポップアップ
// （design/designs/ページ設計.md の 6-5 C6、API設計.md の 16-3-6 ㉔。入力場所はポップアップ。PR212）。
// ボタンを出すかどうかは、学生詳細の側で Rails の available_actions（"scout"）に従って決める。
// 守りは Rails にある（やりとりがもうある・募集が掲載中でないなら 409、スカウト文が空・長すぎるなら 422）。
// 画面側の確かめは、送る手間を省くためだけ。
// 送信後の「この学生に似た学生」のポップアップは、学生詳細の側が onScouted を受けて開く
// （このポップアップは送ったあとボタンごと消えるので、外に置く。順14）

import { useState, type FormEvent } from "react";
import { LongTextField } from "@/components/form-fields";
import { useRedirectIfUnauthorized } from "@/components/member-only";
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
import { ApiError, apiFetch } from "@/lib/api";
import type { CompanyJobPostingState } from "@/lib/company-students";

// スカウト文が空のまま送ろうとしたときの文言。Rails の 422 と同じ（権限_バリデーション.md の 17-3-3）
const BODY_REQUIRED_MESSAGE = "スカウト文を入力してください";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

type ScoutDialogProps = {
  // スカウトに使う募集
  jobPostingId: number;
  jobPostingTitle: string;
  // 送る相手。番号は学生詳細の URL の番号
  studentId: string;
  studentName: string;
  // 送れたとき。返ってきた「その募集の状態」（形D）を渡す
  onScouted: (state: CompanyJobPostingState) => void;
  // 入力の誤り（422）以外で送れなかったとき。message は画面に出す一言
  onFailed: (message: string) => void;
};

export function ScoutDialog({
  jobPostingId,
  jobPostingTitle,
  studentId,
  studentName,
  onScouted,
  onFailed,
}: ScoutDialogProps) {
  const redirectIfUnauthorized = useRedirectIfUnauthorized();
  const [open, setOpen] = useState(false);
  // 入力中のスカウト文
  const [body, setBody] = useState("");
  // スカウト文の欄の下に出すエラー
  const [errors, setErrors] = useState<string[] | undefined>(undefined);
  // 送っている途中か。2回押しても、1回だけ送る。ボタンは押せなくしない（権限_バリデーション.md の 17-3-2）
  const [submitting, setSubmitting] = useState(false);

  // 開くたびに、入力とエラーを空にする
  function handleOpenChange(nextOpen: boolean) {
    if (nextOpen) {
      setBody("");
      setErrors(undefined);
    }
    setOpen(nextOpen);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で送る
    event.preventDefault();
    if (submitting) return;

    // ① 空（空白だけも含む。Rails も空として扱う）なら、送らずにエラーを出す
    if (body.trim() === "") {
      setErrors([BODY_REQUIRED_MESSAGE]);
      return;
    }
    setErrors(undefined);
    setSubmitting(true);

    try {
      // ② スカウトを送る（㉔）。返事は、スカウトしたあとの、その募集の状態（形D）
      const state = await apiFetch<CompanyJobPostingState>("/api/company/scouts", {
        method: "POST",
        body: { job_posting_id: jobPostingId, student_profile_id: studentId, body },
      });
      setOpen(false);
      onScouted(state);
    } catch (error) {
      if (redirectIfUnauthorized(error)) return;
      // ③ 入力の誤り（422。2,000文字を超えた、など）なら、開いたまま、スカウト文の欄の下に出す
      if (error instanceof ApiError && error.status === 422 && error.errors) {
        setErrors(error.errors.body ?? [error.message]);
        return;
      }
      // 今の状態ではできない（409。別のタブでもうスカウトした、募集が終了した、など）ほかは、閉じて一言を出し、取り直す
      setOpen(false);
      onFailed(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger className={buttonVariants()}>スカウトをする</DialogTrigger>
      <DialogContent className="sm:max-w-lg">
        <form onSubmit={handleSubmit} className="grid gap-4">
          <DialogHeader>
            <DialogTitle>{studentName}さんにスカウトを送る</DialogTitle>
            <DialogDescription>
              募集「{jobPostingTitle}」のスカウトとして送ります。スカウト文は、この学生とのメッセージの最初の1通になります。
            </DialogDescription>
          </DialogHeader>
          <LongTextField id="scout-body" label="スカウト文" value={body} onChange={setBody} errors={errors} />
          <DialogFooter>
            <DialogClose render={<Button type="button" variant="outline" />}>キャンセル</DialogClose>
            <Button type="submit">{submitting ? "送信中…" : "送信する"}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
