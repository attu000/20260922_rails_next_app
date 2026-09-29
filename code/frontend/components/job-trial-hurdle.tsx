"use client";

// プチ職業体験（S12）のハードル1つ分。解説（概要・難しさ・コツ・具体例・ゴール）と、選択式の問題。
// 詳しくは design/designs/ページ設計.md の S12、API設計.md の 16-3-9 ㊼。
// 選択肢を選んで「答える」を押すと（PR398）、㊼ で Rails に正否を聞き、正否と選んだ選択肢の解説を出す。
// 間違えたら選び直せる。正解したら親に伝え、親が「次へ」を押せるようにする。
// 正否もやり直しの回数も記録しない（PR355）

import { useState, type FormEvent } from "react";
import { RadioField } from "@/components/form-fields";
import { MarkdownText } from "@/components/markdown-text";
import { useRedirectIfUnauthorized } from "@/components/member-only";
import { Button } from "@/components/ui/button";
import { ApiError, apiFetch } from "@/lib/api";
import type { JobTrialCheckResult, JobTrialHurdle as Hurdle } from "@/lib/job-trials";

// 選ばずに「答える」を押したときの一言
const CHOICE_REQUIRED_MESSAGE = "選択肢を選んでください";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// 解説の5つの小見出しと、ハードルの項目名（並びはこの順）
const SECTIONS = [
  { title: "概要", key: "overview" },
  { title: "難しさ", key: "difficulty" },
  { title: "コツ", key: "tips" },
  { title: "具体例", key: "example" },
  { title: "ゴール", key: "goal" },
] as const;

type JobTrialHurdleProps = {
  hurdle: Hurdle;
  // 講座の中で何番目か（1から数える）。見出しの「ハードル1」に使う
  number: number;
  // 正解したとき
  onPassed: () => void;
};

export function JobTrialHurdle({ hurdle, number, onPassed }: JobTrialHurdleProps) {
  const redirectIfUnauthorized = useRedirectIfUnauthorized();
  // 選んでいる選択肢の key。まだ選んでいなければ空文字
  const [selected, setSelected] = useState("");
  // 最後に答えた結果。選び直したら消す
  const [result, setResult] = useState<JobTrialCheckResult | null>(null);
  // 選択肢の欄の下に出すエラー
  const [errors, setErrors] = useState<string[] | undefined>(undefined);
  // 聞いている途中か。2回押しても、1回だけ送る
  const [checking, setChecking] = useState(false);

  function handleSelect(key: string) {
    setSelected(key);
    setResult(null);
    setErrors(undefined);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で送る
    event.preventDefault();
    if (checking) return;
    if (selected === "") {
      setErrors([CHOICE_REQUIRED_MESSAGE]);
      return;
    }
    setChecking(true);
    try {
      // ㊼ 選んだ選択肢の正否と解説を Rails に聞く（判定は Rails。PR377）
      const checked = await apiFetch<JobTrialCheckResult>(`/api/student/job_trial_hurdles/${hurdle.id}/check`, {
        method: "POST",
        body: { choice: selected },
      });
      setResult(checked);
      if (checked.correct) onPassed();
    } catch (error) {
      if (redirectIfUnauthorized(error)) return;
      setErrors([error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE]);
    } finally {
      setChecking(false);
    }
  }

  return (
    <div className="space-y-6">
      <h2 className="text-lg font-bold">
        ハードル{number}　{hurdle.name}
      </h2>

      {/* 解説。Markdown で書かれているので、そのまま表示の部品に渡す */}
      {SECTIONS.map((section) => (
        <section key={section.key} className="space-y-2">
          <h3 className="font-bold">{section.title}</h3>
          <MarkdownText>{hurdle[section.key]}</MarkdownText>
        </section>
      ))}

      {/* 問題 */}
      <form onSubmit={handleSubmit} noValidate className="space-y-4 rounded-lg border p-4">
        <h3 className="font-bold">問題</h3>
        <MarkdownText>{hurdle.question}</MarkdownText>
        <RadioField
          name={`hurdle-${hurdle.id}-choice`}
          legend="選択肢"
          choices={hurdle.choices.map((choice) => ({ value: choice.key, label: `${choice.key}．${choice.body}` }))}
          value={selected}
          onChange={handleSelect}
          errors={errors}
        />
        <Button type="submit" variant="outline">
          {checking ? "確認中…" : "答える"}
        </Button>
        {/* 正否と、選んだ選択肢の解説。間違えたときも、正解の選択肢は出さない（Rails も返さない）。
            正解の選択肢の解説は「正解。」で始まる（PR394）ので、正解のときは解説だけを出す */}
        {result && (
          <div className="space-y-1 rounded-md bg-secondary p-3 text-sm" aria-live="polite">
            {!result.correct && <p className="font-bold text-destructive">不正解。選び直してください</p>}
            <p>{result.explanation}</p>
          </div>
        )}
      </form>
    </div>
  );
}
