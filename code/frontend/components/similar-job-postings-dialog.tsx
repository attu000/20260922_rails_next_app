"use client";

// 募集詳細（S6）の応募完了のポップアップ（design/designs/ページ設計.md の 6-6 S6、API設計.md の 16-3 ㉝。順14）。
// 開いたら ㉝ この募集に似た募集を取り、募集一覧と同じ行（PR319）で最大5件並べる。
// 選び方（自分の稼働条件に合う募集が先、足りなければ合わない募集から補充）は Rails が行い、画面は並べるだけ。
// 題名は「応募が完了しました」。似た募集が0件なら、小見出しと一覧を出さない（PR320）。
// 応募したときだけ開く（スカウトへのマッチでは開かない。ページ設計.md の 6-6 S6）

import { SimilarList } from "@/components/similar-list";
import { StudentJobPostingRow } from "@/components/student-job-posting-row";
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
import type { Options } from "@/lib/options";
import type { SimilarJobPostingsResult } from "@/lib/student-job-postings";

type SimilarJobPostingsDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  // 応募した募集
  jobPostingId: number;
  options: Options;
};

export function SimilarJobPostingsDialog({ open, onOpenChange, jobPostingId, options }: SimilarJobPostingsDialogProps) {
  // 開いているときだけ取りに行く（閉じているときは null を渡し、呼ばない）
  const { data, error } = useApi<SimilarJobPostingsResult>(
    open ? `/api/student/job_postings/${encodeURIComponent(jobPostingId)}/similar_job_postings` : null,
  );

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>応募が完了しました</DialogTitle>
        </DialogHeader>
        <SimilarList
          loading={!data && !error}
          // 401 は共通の枠がログイン画面へ移すので、ここでは出さない
          errorMessage={error && error.status !== 401 ? error.message : null}
          heading="この募集に似た募集"
          count={data?.items.length ?? 0}
          onLinkClick={() => onOpenChange(false)}
        >
          {data?.items.map((jobPosting) => (
            <StudentJobPostingRow key={jobPosting.id} jobPosting={jobPosting} options={options} />
          ))}
        </SimilarList>
        <DialogFooter>
          <DialogClose render={<Button type="button" variant="outline" />}>閉じる</DialogClose>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
