"use client";

// 学生詳細（C6）の「修了したプチ職業体験」と、自己分析のポップアップ
// （design/designs/ページ設計.md の 6-5 C6、API設計.md の 16-3 ㉓。PR372）。
// 学生ごとの情報なので、募集の選択欄の外（名前の行と選択欄のあいだ）に置く（PR401）。
// 修了した講座の名前を、修了した日の新しい順（Rails の並びのまま）に並べ、押すとその自己分析をポップアップで開く。
// 1つもなければ何も出さない。
// 自己分析の中身は ㉓ にすべて入っているので、開くたびに取りに行かない（PR386）

import { useState, type ReactNode } from "react";
import Link from "next/link";
import { StatusBadge } from "@/components/status-badge";
import { Button, buttonVariants } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { formatDate } from "@/lib/format";
import { SELF_ANALYSIS_QUESTIONS, type CompanySelfAnalysis } from "@/lib/job-trials";
import { labelOf, type Options } from "@/lib/options";

type CompletedJobTrialsProps = {
  selfAnalyses: CompanySelfAnalysis[];
  options: Options;
};

export function CompletedJobTrials({ selfAnalyses, options }: CompletedJobTrialsProps) {
  // 開いている自己分析。閉じていれば null
  const [opened, setOpened] = useState<CompanySelfAnalysis | null>(null);

  if (selfAnalyses.length === 0) return null;

  return (
    <section className="space-y-2">
      <h2 className="text-sm font-bold">修了したプチ職業体験</h2>
      <div className="flex flex-wrap gap-2">
        {selfAnalyses.map((selfAnalysis) => (
          <Button
            key={selfAnalysis.job_trial.id}
            type="button"
            variant="outline"
            size="sm"
            onClick={() => setOpened(selfAnalysis)}
          >
            {selfAnalysis.job_trial.title}
          </Button>
        ))}
      </div>

      <Dialog open={opened !== null} onOpenChange={(open) => !open && setOpened(null)}>
        {/* 中身が長ければ、題名と下のボタンは動かさず、中身だけを縦に動かせるようにする（応募理由のポップアップと同じ） */}
        <DialogContent className="max-h-[85vh] grid-rows-[auto_minmax(0,1fr)_auto] sm:max-w-lg">
          {opened && <SelfAnalysisDialogBody selfAnalysis={opened} options={options} />}
        </DialogContent>
      </Dialog>
    </section>
  );
}

// 選択の答え1行（「いちばん得意なハードル：理解する」）
function AnswerRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="space-y-0.5">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-sm">{children}</dd>
    </div>
  );
}

// 記述1つ。問いの文を小見出しにし、学生が入れた改行はそのまま出す
function WrittenAnswer({ question, answer }: { question: string; answer: string }) {
  return (
    <section className="space-y-1">
      <h3 className="text-sm font-bold">{question}</h3>
      <p className="text-sm whitespace-pre-wrap">{answer}</p>
    </section>
  );
}

// ポップアップの中身。上に選択の答え、下に記述、最後に更新した日と「講座の内容を見る」（ページ設計.md の 6-5 C6）
function SelfAnalysisDialogBody({ selfAnalysis, options }: { selfAnalysis: CompanySelfAnalysis; options: Options }) {
  const reason = options.enums.growth_reason.find((option) => option.value === selfAnalysis.growth_reason);

  return (
    <>
      <DialogHeader>
        <DialogTitle>{selfAnalysis.job_trial.title}</DialogTitle>
        <DialogDescription>自己分析</DialogDescription>
      </DialogHeader>

      <div className="-mx-1 space-y-5 overflow-y-auto px-1">
        {/* 選択の答え */}
        <dl className="space-y-3">
          <AnswerRow label="いちばん得意なハードル">{selfAnalysis.strength_hurdle.name}</AnswerRow>
          <AnswerRow label="いちばん伸ばしたいハードル">
            {selfAnalysis.growth_hurdle.name}
            {/* 1-1 と 2-1 が同じハードル（判定は Rails。PR360） */}
            {selfAnalysis.same_hurdle && (
              <StatusBadge size="sm" className="ml-2">
                得意を伸ばしたい
              </StatusBadge>
            )}
          </AnswerRow>
          <AnswerRow label="伸ばしたい理由">
            {labelOf(options.enums.growth_reason, selfAnalysis.growth_reason) ?? selfAnalysis.growth_reason}
          </AnswerRow>
        </dl>

        {/* 記述。問いの文を小見出しにする。2-3 の問いは、学生が選んだ理由の問い（PR397） */}
        <WrittenAnswer question={SELF_ANALYSIS_QUESTIONS.strength_reason} answer={selfAnalysis.strength_reason} />
        <WrittenAnswer question={reason?.detail_question ?? "伸ばしたい理由の深掘り"} answer={selfAnalysis.growth_detail} />
        <WrittenAnswer question={SELF_ANALYSIS_QUESTIONS.next_step} answer={selfAnalysis.next_step} />

        <p className="text-xs text-muted-foreground">最終更新：{formatDate(selfAnalysis.updated_at)}</p>
      </div>

      <DialogFooter>
        {/* 講座の中身を新しいタブで開く（学生詳細を開いたまま読めるように） */}
        <Link
          href={`/company/job_trials/${selfAnalysis.job_trial.id}`}
          target="_blank"
          rel="noopener noreferrer"
          className={buttonVariants({ variant: "outline" })}
        >
          講座の内容を見る
        </Link>
        <DialogClose render={<Button type="button" />}>閉じる</DialogClose>
      </DialogFooter>
    </>
  );
}
