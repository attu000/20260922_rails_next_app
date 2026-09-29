"use client";

// プチ職業体験（S12）の中身。詳しくは design/designs/ページ設計.md の S12、API設計.md の 16-3-9 ㊻。
// はじめに → ハードルごとに1ステップ → 自己分析、を1つの URL の中で進む（PR388。新規登録と同じ作り）。
// 開いたときに ㊻ で講座の中身と自分の自己分析を1回だけ取り、あとは画面の中だけでステップを切り替える。
// ボタンでだけ次へ進み、ハードルは正解するまで「次へ」を押せない。
// 途中の状態は保存しない。読み込み直すと初めから（PR371）。
// 修了済み（自己分析がある）なら、はじめにに「自己分析を書き直す」を出し、前の回答が入った自己分析へ直接進める。
// 講座を最後まで通ったかは Rails では確かめない（PR387）

import { useState } from "react";
import { useRouter } from "next/navigation";
import { JobTrialHurdle } from "@/components/job-trial-hurdle";
import { MarkdownText } from "@/components/markdown-text";
import { PageTitle } from "@/components/page-title";
import { SelfAnalysisForm } from "@/components/self-analysis-form";
import { StatusBadge } from "@/components/status-badge";
import { Button } from "@/components/ui/button";
import { useApi } from "@/lib/api";
import type { JobTrialDetail } from "@/lib/job-trials";
import { jobMiddleCategoryNames, namesOf, useOptions } from "@/lib/options";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// 今のステップ。数はハードルの並びの中の位置（0から数える）
type Step = "intro" | number | "self_analysis";

export function StudentJobTrial({ jobTrialId }: { jobTrialId: string }) {
  const router = useRouter();
  const { options, failed: optionsFailed } = useOptions();
  const { data, error } = useApi<JobTrialDetail>(`/api/student/job_trials/${jobTrialId}`, {
    // ステップを進めている途中で取り直して画面が変わらないよう、画面に戻ってきても取り直さない
    revalidateOnFocus: false,
  });

  const [step, setStep] = useState<Step>("intro");
  // この画面で正解したハードルの番号。戻って進み直しても、答え直さなくてよい
  const [passedHurdleIds, setPassedHurdleIds] = useState<number[]>([]);
  // 自己分析の「戻る」で戻る先。講座から来たら最後のハードル、「自己分析を書き直す」から来たら、はじめに
  const [stepBeforeSelfAnalysis, setStepBeforeSelfAnalysis] = useState<Step>("intro");

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  // ㊻ が取れなかった（存在しない番号なら「見つかりません」）。401 は共通の枠がログイン画面へ移すので、読み込み中のままにする
  if (!data && error && error.status !== 401) {
    return <p className="text-sm text-destructive">{error.message}</p>;
  }

  if (!options || !data) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  const { masters } = options;
  const hurdles = data.hurdles;
  const lastHurdleIndex = hurdles.length - 1;
  // 「中分類 ／ 工程・工程」の1行（一覧と同じ書き方）
  const summary = [
    jobMiddleCategoryNames(masters.job_major_categories, [data.job_middle_category_id]).join("・"),
    namesOf(masters.work_processes, data.work_process_ids).join("・"),
  ]
    .filter((names) => names !== "")
    .join(" ／ ");

  function goToStep(next: Step) {
    setStep(next);
    // 次のステップは、画面の上から見せる
    window.scrollTo({ top: 0 });
  }

  function goToSelfAnalysis(from: Step) {
    setStepBeforeSelfAnalysis(from);
    goToStep("self_analysis");
  }

  let content;
  if (step === "intro") {
    content = (
      <div className="space-y-6">
        <section className="space-y-2">
          <h2 className="text-lg font-bold">はじめに</h2>
          <MarkdownText>{data.intro}</MarkdownText>
        </section>
        <div className="flex flex-wrap gap-2">
          {/* 修了済みでも、講座を初めから読み直せる */}
          <Button type="button" onClick={() => goToStep(0)}>
            講座を始める
          </Button>
          {/* 修了済みのときだけ出す。修了していない学生は、講座を通らずに自己分析を書けない（PR387） */}
          {data.self_analysis && (
            <Button type="button" variant="outline" onClick={() => goToSelfAnalysis("intro")}>
              自己分析を書き直す
            </Button>
          )}
        </div>
      </div>
    );
  } else if (step === "self_analysis") {
    content = (
      <SelfAnalysisForm
        jobTrialId={data.id}
        hurdles={hurdles}
        initial={data.self_analysis}
        growthReasons={options.enums.growth_reason}
        onBack={() => goToStep(stepBeforeSelfAnalysis)}
        // 送ったら一覧へ（ページ設計.md の S12）。一覧は開いたときに取り直すので、「修了済み」の札が付く
        onSaved={() => router.push("/student/job_trials")}
      />
    );
  } else {
    const hurdle = hurdles[step];
    const passed = passedHurdleIds.includes(hurdle.id);
    const isLast = step === lastHurdleIndex;
    content = (
      <div className="space-y-6">
        {/* key を変えて、ハードルが変わるたびに選んだ選択肢と結果を空にする */}
        <JobTrialHurdle
          key={hurdle.id}
          hurdle={hurdle}
          number={step + 1}
          onPassed={() => setPassedHurdleIds((current) => (current.includes(hurdle.id) ? current : [...current, hurdle.id]))}
        />
        <div className="flex gap-2">
          <Button type="button" variant="outline" onClick={() => goToStep(step === 0 ? "intro" : step - 1)}>
            戻る
          </Button>
          {/* 正解するまで押せない（ページ設計.md の S12） */}
          <Button
            type="button"
            disabled={!passed}
            onClick={() => (isLast ? goToSelfAnalysis(step) : goToStep(step + 1))}
          >
            {isLast ? "自己分析へ" : "次へ"}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="space-y-1">
        <PageTitle>
          {data.title}
          {/* 修了済み。見た目は、一覧の札とそろえる（同じ部品） */}
          {data.self_analysis && (
            <StatusBadge size="sm" className="ml-2 align-middle">
              修了済み
            </StatusBadge>
          )}
        </PageTitle>
        {summary !== "" && <p className="text-sm text-muted-foreground">{summary}</p>}
      </div>
      {content}
    </div>
  );
}
