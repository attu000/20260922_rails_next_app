"use client";

// プチ職業体験の内容（C11）の中身。詳しくは design/designs/ページ設計.md の C11、API設計.md の 16-3-9 ㊾。
// 企業が、学生の自己分析が何の話をしているかを知るために、講座の中身を読む（PR373）。読むだけ。
// 開いたら ㊾ 講座の中身（正解と解説を含む）と ⑦ 選択肢（中分類・工程の名前、2-3 の問い）を取る。
// 企業は問題を解かないので、正解と選択肢ごとの解説を最初から出す。
// 最後に、学生が聞かれた自己分析の問いを並べる

import { HurdleExplanation } from "@/components/job-trial-hurdle";
import { MarkdownText } from "@/components/markdown-text";
import { PageTitle } from "@/components/page-title";
import { StatusBadge } from "@/components/status-badge";
import { useApi } from "@/lib/api";
import { SELF_ANALYSIS_GUIDE, SELF_ANALYSIS_QUESTIONS, type CompanyJobTrial as Detail } from "@/lib/job-trials";
import { jobMiddleCategoryNames, namesOf, useOptions } from "@/lib/options";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

export function CompanyJobTrial({ jobTrialId }: { jobTrialId: string }) {
  const { options, failed: optionsFailed } = useOptions();
  const { data, error } = useApi<Detail>(`/api/company/job_trials/${jobTrialId}`);

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  // ㊾ が取れなかった（存在しない番号なら「見つかりません」）。401 は共通の枠がログイン画面へ移すので、読み込み中のままにする
  if (!data && error && error.status !== 401) {
    return <p className="text-sm text-destructive">{error.message}</p>;
  }

  if (!options || !data) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  const { masters } = options;
  // 「中分類 ／ 工程・工程」の1行（学生のプチ職業体験一覧と同じ書き方）
  const summary = [
    jobMiddleCategoryNames(masters.job_major_categories, [data.job_middle_category_id]).join("・"),
    namesOf(masters.work_processes, data.work_process_ids).join("・"),
  ]
    .filter((names) => names !== "")
    .join(" ／ ");
  const growthReasons = options.enums.growth_reason;

  return (
    <div className="space-y-8">
      <div className="space-y-1">
        <PageTitle>{data.title}</PageTitle>
        {summary !== "" && <p className="text-sm text-muted-foreground">{summary}</p>}
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-bold">はじめに</h2>
        <MarkdownText>{data.intro}</MarkdownText>
      </section>

      {/* ハードルごとに、解説と、問題・正解・選択肢ごとの解説 */}
      {data.hurdles.map((hurdle, index) => (
        <section key={hurdle.id} className="space-y-6 rounded-lg border p-4">
          <h2 className="text-lg font-bold">
            ハードル{index + 1}　{hurdle.name}
          </h2>
          <HurdleExplanation hurdle={hurdle} />
          <section className="space-y-3">
            <h3 className="font-bold">問題</h3>
            <MarkdownText>{hurdle.question}</MarkdownText>
            <ul className="space-y-3">
              {hurdle.choices.map((choice) => (
                <li key={choice.key} className="space-y-1 text-sm">
                  <p>
                    {choice.key}．{choice.body}
                    {choice.correct && (
                      <StatusBadge size="sm" className="ml-2">
                        正解
                      </StatusBadge>
                    )}
                  </p>
                  <p className="text-muted-foreground">{choice.explanation}</p>
                </li>
              ))}
            </ul>
          </section>
        </section>
      ))}

      {/* 学生が聞かれた自己分析の問い（サービス概要_コンセプト.md の 12-4）。学生詳細のポップアップの答えと見比べられるように */}
      <section className="space-y-4 rounded-lg border p-4">
        <h2 className="text-lg font-bold">自己分析の問い</h2>
        <p className="text-sm text-muted-foreground">{SELF_ANALYSIS_GUIDE}</p>
        <ol className="list-decimal space-y-3 pl-5 text-sm">
          <li>{SELF_ANALYSIS_QUESTIONS.strength_hurdle}</li>
          <li>
            {SELF_ANALYSIS_QUESTIONS.strength_reason}
            {SELF_ANALYSIS_QUESTIONS.strength_reason_note}
          </li>
          <li>{SELF_ANALYSIS_QUESTIONS.growth_hurdle}</li>
          <li className="space-y-1">
            <p>{SELF_ANALYSIS_QUESTIONS.growth_reason}</p>
            <ul className="list-disc pl-5 text-muted-foreground">
              {growthReasons.map((reason) => (
                <li key={reason.value}>{reason.label}</li>
              ))}
            </ul>
          </li>
          <li className="space-y-1">
            <p>選んだ理由に応じて、次のどれかを聞く</p>
            <ul className="list-disc pl-5 text-muted-foreground">
              {growthReasons.map((reason) => (
                <li key={reason.value}>
                  {reason.label}：{reason.detail_question}
                </li>
              ))}
            </ul>
          </li>
          <li>{SELF_ANALYSIS_QUESTIONS.next_step}</li>
        </ol>
      </section>
    </div>
  );
}
