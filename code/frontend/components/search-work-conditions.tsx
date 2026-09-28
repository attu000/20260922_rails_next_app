// 募集一覧（学生のホーム）の [稼働条件] のポップアップの中身（PR200）。
// 学生側の言い方（無理なく続けられる範囲の上限）で並べる（design/designs/その他決め事.md の 5-6）。
// 「合うかどうか」の判定は Rails が行う（API設計.md の 16-3 ⑱）。ここは選ぶだけ。
// 「自分の稼働条件で選ぶ」ボタンは、並び順とは関係なく、押したときだけ下書きを埋める（PR302）

import { ChoiceButtons } from "@/components/choice-buttons";
import { MonthField } from "@/components/form-fields";
import { Checkbox } from "@/components/ui/checkbox";
import { Field, FieldGroup, FieldLabel, FieldLegend, FieldSet } from "@/components/ui/field";
import { currentYearInTokyo, joinMonthDate, splitMonthDate, yearChoices } from "@/lib/form-values";
import type { Options } from "@/lib/options";
import type { SearchConditions } from "@/lib/student-job-postings";
import type { StudentProfile } from "@/lib/student-profile";

// ポップアップの中で持つ下書き。開始時期は、年と月の片方だけ選んだ状態も持てるよう、2つの文字で持つ
export type WorkConditionsDraft = {
  work_days_per_week: number | null;
  work_hours_per_day: number | null;
  duration_months: number | null;
  start_year: string;
  start_month: string;
  work_styles: string[];
  weekend_ok: boolean;
};

// 検索の条件 → 下書き
export function toWorkConditionsDraft(conditions: SearchConditions): WorkConditionsDraft {
  const { year, month } = splitMonthDate(conditions.available_from);
  return {
    work_days_per_week: conditions.work_days_per_week,
    work_hours_per_day: conditions.work_hours_per_day,
    duration_months: conditions.duration_months,
    start_year: year,
    start_month: month,
    work_styles: conditions.work_styles,
    weekend_ok: conditions.weekend_ok,
  };
}

// 下書き → 検索の条件の稼働条件の部分。年と月の片方だけのときは、呼ぶ側が先に止める
export function fromWorkConditionsDraft(draft: WorkConditionsDraft) {
  return {
    work_days_per_week: draft.work_days_per_week,
    work_hours_per_day: draft.work_hours_per_day,
    duration_months: draft.duration_months,
    available_from: joinMonthDate(draft.start_year, draft.start_month),
    work_styles: draft.work_styles,
    weekend_ok: draft.weekend_ok,
  };
}

// プロフィールの稼働条件 → 下書き（「自分の稼働条件で選ぶ」。PR302）。
// 入力済みの項目だけを選び、未入力の項目はオフにする（その他決め事.md の 5-10）。
// 勤務形態は、3つとも可能なら選ばない（「未入力」と「すべて可能」は区別しない。5-6）。
// 土日OK はプロフィールにない項目なので、今の選択のまま
export function workConditionsDraftFromProfile(
  profile: StudentProfile,
  current: WorkConditionsDraft,
): WorkConditionsDraft {
  const { year, month } = splitMonthDate(profile.available_from);
  const possibleStyles = [
    profile.can_full_remote ? "full_remote" : null,
    profile.can_partial_remote ? "partial_remote" : null,
    profile.can_onsite ? "onsite" : null,
  ].filter((style) => style !== null);
  return {
    work_days_per_week: profile.work_days_per_week,
    work_hours_per_day: profile.work_hours_per_day,
    duration_months: profile.duration_months,
    start_year: year,
    start_month: month,
    work_styles: possibleStyles.length === 3 ? [] : possibleStyles,
    weekend_ok: current.weekend_ok,
  };
}

// 指定している条件の数（[稼働条件（2）] のボタンに出す）
export function countWorkConditions(draft: WorkConditionsDraft): number {
  return [
    draft.work_days_per_week !== null,
    draft.work_hours_per_day !== null,
    draft.duration_months !== null,
    draft.start_year !== "" || draft.start_month !== "",
    draft.work_styles.length > 0,
    draft.weekend_ok,
  ].filter(Boolean).length;
}

// 何も指定していない下書き（「この条件をクリア」）
export const EMPTY_WORK_CONDITIONS: WorkConditionsDraft = {
  work_days_per_week: null,
  work_hours_per_day: null,
  duration_months: null,
  start_year: "",
  start_month: "",
  work_styles: [],
  weekend_ok: false,
};

type SearchWorkConditionsProps = {
  options: Options;
  draft: WorkConditionsDraft;
  onChange: (draft: WorkConditionsDraft) => void;
  // 開始時期の確認で見つかったエラー（「開始時期は年と月の両方を選んでください」）
  startMonthErrors?: string[];
};

export function SearchWorkConditions({ options, draft, onChange, startMonthErrors }: SearchWorkConditionsProps) {
  const { work_conditions: choices } = options;
  const currentYear = currentYearInTokyo();

  function update<K extends keyof WorkConditionsDraft>(key: K, value: WorkConditionsDraft[K]) {
    onChange({ ...draft, [key]: value });
  }

  function toggleWorkStyle(value: string, checked: boolean) {
    update("work_styles", checked ? [...draft.work_styles, value] : draft.work_styles.filter((style) => style !== value));
  }

  return (
    <FieldGroup>
      {/* ボタンの数値は、選択肢の窓口（⑦）が返す稼働条件の数値（マイページと同じ） */}
      <ChoiceButtons
        legend="週に働ける日数"
        choices={choices.work_days_per_week.map((n) => ({ value: n, label: `週${n}日まで` }))}
        value={draft.work_days_per_week}
        onChange={(value) => update("work_days_per_week", value)}
      />
      <ChoiceButtons
        legend="1日に働ける時間"
        choices={choices.work_hours_per_day.map((n) => ({ value: n, label: `${n}時間まで` }))}
        value={draft.work_hours_per_day}
        onChange={(value) => update("work_hours_per_day", value)}
      />
      <ChoiceButtons
        legend="続けられる期間"
        choices={choices.duration_months.map((n) => ({ value: n, label: `${n}ヶ月以上` }))}
        value={draft.duration_months}
        onChange={(value) => update("duration_months", value)}
      />

      {/* 年と月の2つの選択欄。年の選択肢は、マイページと同じ1年前〜2年後 */}
      <MonthField
        id="search-start-year"
        label="働き始められる時期"
        year={draft.start_year}
        month={draft.start_month}
        onYearChange={(value) => update("start_year", value)}
        onMonthChange={(value) => update("start_month", value)}
        years={yearChoices(currentYear - 1, currentYear + 2, draft.start_year)}
        errors={startMonthErrors}
        description="随時の募集と、すでに始まっている募集は、いつでも条件に合います"
      />

      {/* 勤務形態：選んだものに、募集の勤務形態が含まれれば合う。表示名は ⑦ の enums.work_style */}
      <FieldSet>
        <FieldLegend variant="label">働ける勤務形態</FieldLegend>
        <div className="flex flex-wrap gap-4">
          {options.enums.work_style.map((style) => {
            const id = `search-work-style-${style.value}`;
            return (
              <Field key={style.value} orientation="horizontal" className="w-auto">
                <Checkbox
                  id={id}
                  checked={draft.work_styles.includes(style.value)}
                  onCheckedChange={(checked) => toggleWorkStyle(style.value, checked)}
                />
                <FieldLabel htmlFor={id} className="font-normal">
                  {style.label}
                </FieldLabel>
              </Field>
            );
          })}
        </div>
      </FieldSet>

      <Field orientation="horizontal">
        <Checkbox
          id="search-weekend-ok"
          checked={draft.weekend_ok}
          onCheckedChange={(checked) => update("weekend_ok", checked)}
        />
        <FieldLabel htmlFor="search-weekend-ok" className="font-normal">
          土日に働ける募集だけ
        </FieldLabel>
      </Field>
    </FieldGroup>
  );
}
