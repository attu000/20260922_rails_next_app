"use client";

// 学生詳細（C6）の「修了したプチ職業体験」と、自己分析のポップアップ
// （design/designs/ページ設計.md の 6-5 C6、API設計.md の 16-3 ㉓。PR372）。
// 学生ごとの情報なので、募集の選択欄の外に置く。場所は学生詳細のいちばん下（プロフィールの「稼働条件」の下）。
// 修了した講座の名前を、修了した日の新しい順（Rails の並びのまま）に並べ、押すとその自己分析をポップアップで開く。
// 1つもなければ何も出さない。
// ポップアップは、企業が答えを判断できるよう、先に講座の説明と各ハードルで見ている力を出し、そのあとに学生の答えを出す（PR402〜PR404）。
// 講座の説明と力は、講座のファイルの guide から Rails が入れる。書いていなければ、その部分を出さない（PR407）。
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
import { Separator } from "@/components/ui/separator";
import { formatDate } from "@/lib/format";
import { SELF_ANALYSIS_QUESTIONS, type CompanySelfAnalysis, type CompanySelfAnalysisJobTrial } from "@/lib/job-trials";
import { jobMiddleCategoryNames, labelOf, namesOf, type Options } from "@/lib/options";

// ハードルの番号の印（①②…）。講座のハードルは4つ程度なので、10を超えたら数字にする
const CIRCLED_NUMBERS = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩"];

function hurdleNumber(index: number): string {
  return CIRCLED_NUMBERS[index] ?? `${index + 1}.`;
}

// 「① 理解する：情報を整理する力」。力が書かれていなければ「① 理解する」
function hurdleLabel(jobTrial: CompanySelfAnalysisJobTrial, hurdleId: number, fallbackName: string): string {
  const index = jobTrial.hurdles.findIndex((hurdle) => hurdle.id === hurdleId);
  if (index === -1) return fallbackName;
  const hurdle = jobTrial.hurdles[index];
  return `${hurdleNumber(index)} ${hurdle.name}${hurdle.skill ? `：${hurdle.skill}` : ""}`;
}

type CompletedJobTrialsProps = {
  selfAnalyses: CompanySelfAnalysis[];
  // ポップアップの文の「〇〇さん」に使う
  studentName: string;
  options: Options;
};

export function CompletedJobTrials({ selfAnalyses, studentName, options }: CompletedJobTrialsProps) {
  // 開いている自己分析。閉じていれば null
  const [opened, setOpened] = useState<CompanySelfAnalysis | null>(null);

  if (selfAnalyses.length === 0) return null;

  return (
    // 見た目は、プロフィールのまとまり（基本情報など）とそろえる
    <section className="space-y-3 rounded-lg border p-4">
      <h2 className="font-bold">修了したプチ職業体験</h2>
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
        {/* 文が多いので、広めにする。題名と下のボタンは動かさず、中身だけを縦に動かせるようにする */}
        <DialogContent className="max-h-[85vh] grid-rows-[auto_minmax(0,1fr)_auto] sm:max-w-2xl">
          {opened && <SelfAnalysisDialogBody selfAnalysis={opened} studentName={studentName} options={options} />}
        </DialogContent>
      </Dialog>
    </section>
  );
}

// 選択の答え1行（「いちばん得意なハードル」「① 理解する：情報を整理する力」）
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
      <h4 className="text-sm font-bold">{question}</h4>
      <p className="text-sm whitespace-pre-wrap">{answer}</p>
    </section>
  );
}

type SelfAnalysisDialogBodyProps = {
  selfAnalysis: CompanySelfAnalysis;
  studentName: string;
  options: Options;
};

// ポップアップの中身。上に講座の説明と各ハードルの力、下に学生の答え（答えた順）、最後に更新した日と「講座の内容を見る」
function SelfAnalysisDialogBody({ selfAnalysis, studentName, options }: SelfAnalysisDialogBodyProps) {
  const jobTrial = selfAnalysis.job_trial;
  const { masters } = options;
  // 「中分類 ／ 工程・工程」の1行（プチ職業体験一覧と同じ書き方）
  const summaryLine = [
    jobMiddleCategoryNames(masters.job_major_categories, [jobTrial.job_middle_category_id]).join("・"),
    namesOf(masters.work_processes, jobTrial.work_process_ids).join("・"),
  ]
    .filter((names) => names !== "")
    .join(" ／ ");
  const reason = options.enums.growth_reason.find((option) => option.value === selfAnalysis.growth_reason);

  return (
    <>
      <DialogHeader>
        <DialogTitle>{jobTrial.title}</DialogTitle>
        {summaryLine !== "" && <DialogDescription>{summaryLine}</DialogDescription>}
      </DialogHeader>

      <div className="-mx-1 space-y-5 overflow-y-auto px-1">
        {/* 講座の説明と、各ハードルで見ている力 */}
        <section className="space-y-4">
          <p className="text-sm">
            {jobTrial.summary}
            {jobTrial.title}には次の{jobTrial.hurdles.length}つのハードルがあります。
            {studentName}さんは、これらを体験して振り返りました。
          </p>
          <ol className="space-y-3">
            {jobTrial.hurdles.map((hurdle, index) => (
              <li key={hurdle.id} className="space-y-1 text-sm">
                <h3 className="font-bold">
                  {hurdleNumber(index)} {hurdle.name}
                  {hurdle.skill && `：${hurdle.skill}`}
                </h3>
                {hurdle.skill_description && <p>{hurdle.skill_description}</p>}
                {hurdle.skill_point && <p className="text-muted-foreground">→ {hurdle.skill_point}</p>}
              </li>
            ))}
          </ol>
        </section>

        <Separator />

        {/* 学生の答え。文脈が分かるよう、学生が答えた順に並べる：
            得意なハードル → その理由 → 伸ばしたいハードル → その理由（種類と深掘り）→ 次に知りたいこと。
            記述は、問いの文を小見出しにする。2-3 の問いは、学生が選んだ理由の問い（PR397） */}
        <section className="space-y-4">
          <p className="text-sm">{studentName}さんはこの体験を振り返って、次のようにまとめました。</p>
          <dl>
            <AnswerRow label="いちばん得意なハードル">
              {hurdleLabel(jobTrial, selfAnalysis.strength_hurdle.id, selfAnalysis.strength_hurdle.name)}
            </AnswerRow>
          </dl>
          <WrittenAnswer question={SELF_ANALYSIS_QUESTIONS.strength_reason} answer={selfAnalysis.strength_reason} />
          <dl className="space-y-3">
            <AnswerRow label="いちばん伸ばしたいハードル">
              {hurdleLabel(jobTrial, selfAnalysis.growth_hurdle.id, selfAnalysis.growth_hurdle.name)}
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
          <WrittenAnswer
            question={reason?.detail_question ?? "伸ばしたい理由の深掘り"}
            answer={selfAnalysis.growth_detail}
          />
          <WrittenAnswer question={SELF_ANALYSIS_QUESTIONS.next_step} answer={selfAnalysis.next_step} />

          <p className="text-xs text-muted-foreground">最終更新：{formatDate(selfAnalysis.updated_at)}</p>
        </section>
      </div>

      <DialogFooter>
        {/* 講座の中身を新しいタブで開く（学生詳細を開いたまま読めるように） */}
        <Link
          href={`/company/job_trials/${jobTrial.id}`}
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
