"use client";

// 学生詳細（C6）のスカウト送信後のポップアップ（design/designs/ページ設計.md の 6-5 C6、API設計.md の 16-3 ㉕。順14）。
// 開いたら ㉕ この学生に似た学生を取り、学生検索と同じ行（PR319）で最大5人並べる。
// 選び方（稼働条件に合う学生が先、足りなければ合わない学生から補充）は Rails が行い、画面は並べるだけ。
// 題名は「スカウトを送りました」。似た学生が0人なら、小見出しと一覧を出さない（PR320）。
// 行を押すと、その学生の学生詳細を、スカウトに使った募集を選んだ状態で開く（続けて同じ募集でスカウトしやすいように。PR315）

import { CompanyStudentRow } from "@/components/company-student-row";
import { SimilarList } from "@/components/similar-list";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useApi } from "@/lib/api";
import type { SimilarStudentsResult } from "@/lib/company-students";
import type { Options } from "@/lib/options";

type SimilarStudentsDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  // スカウトした学生（学生詳細の URL の番号）と、スカウトに使った募集
  studentId: string;
  jobPostingId: number;
  options: Options;
};

export function SimilarStudentsDialog({ open, onOpenChange, studentId, jobPostingId, options }: SimilarStudentsDialogProps) {
  // 開いているときだけ取りに行く（閉じているときは null を渡し、呼ばない）
  const { data, error } = useApi<SimilarStudentsResult>(
    open
      ? `/api/company/students/${encodeURIComponent(studentId)}/similar_students?job_posting_id=${encodeURIComponent(jobPostingId)}`
      : null,
  );

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>スカウトを送りました</DialogTitle>
        </DialogHeader>
        <SimilarList
          loading={!data && !error}
          // 401 は共通の枠がログイン画面へ移すので、ここでは出さない
          errorMessage={error && error.status !== 401 ? error.message : null}
          heading="この学生に似た学生"
          count={data?.items.length ?? 0}
          onLinkClick={() => onOpenChange(false)}
        >
          {data?.items.map((student) => (
            <CompanyStudentRow
              key={student.id}
              student={student}
              options={options}
              jobPostingId={String(jobPostingId)}
              tag={null}
            />
          ))}
        </SimilarList>
        <DialogFooter>
          <DialogClose render={<Button type="button" variant="outline" />}>閉じる</DialogClose>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
