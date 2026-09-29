"use client";

// プチ職業体験（S12）の最後のステップ、自己分析の6問。
// 詳しくは design/designs/サービス概要_コンセプト.md の 12-4、ページ設計.md の S12、API設計.md の 16-3-9 ㊽。
// 「送る」で ㊽ に送り、あれば上書き、なければ作る（1人×1講座に1件。PR371）。
// 画面側では確かめず、Rails の 422 の理由を各欄の下に出す（守りは Rails。1ステップだけなので、送って答えを出す）。
// 2-3 の深掘りの問いは、2-2 で選んだ理由の種類の文を ⑦ から引いて出す（PR397）

import { useEffect, useRef, useState, type FormEvent } from "react";
import { LongTextField, RadioField, RequiredNote, type FieldErrors } from "@/components/form-fields";
import { useRedirectIfUnauthorized } from "@/components/member-only";
import { Button } from "@/components/ui/button";
import { FieldGroup } from "@/components/ui/field";
import { ApiError, apiFetch } from "@/lib/api";
import {
  SELF_ANALYSIS_GUIDE,
  SELF_ANALYSIS_QUESTIONS,
  type JobTrialHurdle,
  type SelfAnalysis,
} from "@/lib/job-trials";
import type { GrowthReasonOption } from "@/lib/options";

// 記述3つの文字数の上限。Rails と同じ値（app/models/self_analysis.rb の TEXT_MAX_LENGTH。PR391）
const TEXT_MAX_LENGTH = 400;

// 入力に誤りがあるときに、画面の上に出す一言（Rails の 422 と同じ）
const INVALID_MESSAGE = "入力内容を確認してください";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// 入力中の値。選択は番号・名前を文字で持ち、選んでいなければ空文字
type SelfAnalysisValues = {
  strength_hurdle_id: string;
  strength_reason: string;
  growth_hurdle_id: string;
  growth_reason: string;
  growth_detail: string;
  next_step: string;
};

// 前の回答があれば、それを最初から入れておく（書き直し。PR388）
function toValues(selfAnalysis: SelfAnalysis | null): SelfAnalysisValues {
  return {
    strength_hurdle_id: selfAnalysis ? String(selfAnalysis.strength_hurdle_id) : "",
    strength_reason: selfAnalysis?.strength_reason ?? "",
    growth_hurdle_id: selfAnalysis ? String(selfAnalysis.growth_hurdle_id) : "",
    growth_reason: selfAnalysis?.growth_reason ?? "",
    growth_detail: selfAnalysis?.growth_detail ?? "",
    next_step: selfAnalysis?.next_step ?? "",
  };
}

type SelfAnalysisFormProps = {
  jobTrialId: number;
  // 1-1・2-1 の選択肢（講座の中の順番）
  hurdles: JobTrialHurdle[];
  // 前の回答。なければ null
  initial: SelfAnalysis | null;
  // ⑦ の enums.growth_reason（2-2 の選択肢と、2-3 の問い）
  growthReasons: GrowthReasonOption[];
  // 「戻る」を押したとき
  onBack: () => void;
  // 保存できたとき
  onSaved: () => void;
};

export function SelfAnalysisForm({ jobTrialId, hurdles, initial, growthReasons, onBack, onSaved }: SelfAnalysisFormProps) {
  const redirectIfUnauthorized = useRedirectIfUnauthorized();
  const [values, setValues] = useState<SelfAnalysisValues>(() => toValues(initial));
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  // 画面の上に出す一言
  const [message, setMessage] = useState<string | null>(null);
  // 送っている途中か。2回押しても、1回だけ送る。ボタンは押せなくしない（権限_バリデーション.md の 17-3-2）
  const [submitting, setSubmitting] = useState(false);
  // 増えたら、最初のエラーの項目まで画面を動かす（17-3-2。新規登録と同じ）
  const [scrollToErrorRequest, setScrollToErrorRequest] = useState(0);

  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (scrollToErrorRequest === 0) return;
    formRef.current
      ?.querySelector('[data-slot="field-error"]')
      ?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [scrollToErrorRequest]);

  function change(key: keyof SelfAnalysisValues, value: string) {
    setValues((current) => ({ ...current, [key]: value }));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で送る
    event.preventDefault();
    if (submitting) return;
    setSubmitting(true);
    setMessage(null);

    try {
      // ㊽ 送る。選んでいないハードルは null にする（Rails が「入力してください」を返す）
      await apiFetch<SelfAnalysis>(`/api/student/job_trials/${jobTrialId}/self_analysis`, {
        method: "PUT",
        body: {
          ...values,
          strength_hurdle_id: values.strength_hurdle_id === "" ? null : Number(values.strength_hurdle_id),
          growth_hurdle_id: values.growth_hurdle_id === "" ? null : Number(values.growth_hurdle_id),
          growth_reason: values.growth_reason === "" ? null : values.growth_reason,
        },
      });
    } catch (error) {
      setSubmitting(false);
      if (redirectIfUnauthorized(error)) return;
      // 入力の誤り（422）なら、各欄の下に出す
      if (error instanceof ApiError && error.status === 422 && error.errors) {
        setFieldErrors(error.errors);
        setMessage(INVALID_MESSAGE);
        setScrollToErrorRequest((count) => count + 1);
        return;
      }
      // 同時に2回送られた（409）ほかは、上に一言を出す
      setMessage(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
      return;
    }
    // 移り終わるまで submitting は true のまま（その間に押されても送らない）
    onSaved();
  }

  const hurdleChoices = hurdles.map((hurdle) => ({ value: String(hurdle.id), label: hurdle.name }));
  // 2-2 で選んだ理由の種類。選ぶまでは 2-3 を出さない
  const selectedReason = growthReasons.find((reason) => reason.value === values.growth_reason);

  return (
    <form ref={formRef} onSubmit={handleSubmit} noValidate className="space-y-6">
      <div className="space-y-2">
        <h2 className="text-lg font-bold">自己分析</h2>
        <p className="text-sm">{SELF_ANALYSIS_GUIDE}</p>
        <RequiredNote />
      </div>
      {message && <p className="text-sm text-destructive">{message}</p>}

      <FieldGroup>
        <RadioField
          name="strength_hurdle_id"
          legend={SELF_ANALYSIS_QUESTIONS.strength_hurdle}
          choices={hurdleChoices}
          value={values.strength_hurdle_id}
          onChange={(value) => change("strength_hurdle_id", value)}
          errors={fieldErrors.strength_hurdle_id}
          required
        />
        <LongTextField
          id="strength_reason"
          label={SELF_ANALYSIS_QUESTIONS.strength_reason}
          description={SELF_ANALYSIS_QUESTIONS.strength_reason_note}
          value={values.strength_reason}
          onChange={(value) => change("strength_reason", value)}
          errors={fieldErrors.strength_reason}
          maxLength={TEXT_MAX_LENGTH}
          required
        />
        <RadioField
          name="growth_hurdle_id"
          legend={SELF_ANALYSIS_QUESTIONS.growth_hurdle}
          choices={hurdleChoices}
          value={values.growth_hurdle_id}
          onChange={(value) => change("growth_hurdle_id", value)}
          errors={fieldErrors.growth_hurdle_id}
          required
        />
        <RadioField
          name="growth_reason"
          legend={SELF_ANALYSIS_QUESTIONS.growth_reason}
          choices={growthReasons}
          value={values.growth_reason}
          onChange={(value) => change("growth_reason", value)}
          errors={fieldErrors.growth_reason}
          required
        />
        {selectedReason && (
          <LongTextField
            id="growth_detail"
            label={selectedReason.detail_question}
            value={values.growth_detail}
            onChange={(value) => change("growth_detail", value)}
            errors={fieldErrors.growth_detail}
            maxLength={TEXT_MAX_LENGTH}
            required
          />
        )}
        <LongTextField
          id="next_step"
          label={SELF_ANALYSIS_QUESTIONS.next_step}
          value={values.next_step}
          onChange={(value) => change("next_step", value)}
          errors={fieldErrors.next_step}
          maxLength={TEXT_MAX_LENGTH}
          required
        />
        <div className="flex gap-2">
          <Button type="button" variant="outline" onClick={onBack}>
            戻る
          </Button>
          <Button type="submit">{submitting ? "送信中…" : "送る"}</Button>
        </div>
      </FieldGroup>
    </form>
  );
}
