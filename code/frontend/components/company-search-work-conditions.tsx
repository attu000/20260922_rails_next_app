// 学生検索（C5）の [稼働条件] のポップアップの中身。
// 企業側の言い方（募集で求める下限：週◯日以上など）で並べる。学生の上限がこの値以上なら合う（その他決め事.md の 5-6）。
// 「合うかどうか」の判定は Rails が行う（API設計.md の 16-3 ㉒）。ここは選ぶだけ。
// 募集を選ぶと、その募集の稼働条件で自動で選ぶ仕組みは後で足す（PR214）

import { ChoiceButtons } from "@/components/choice-buttons";
import { MonthField } from "@/components/form-fields";
import { Field, FieldDescription, FieldGroup, FieldLabel } from "@/components/ui/field";
import { NativeSelect, NativeSelectOption } from "@/components/ui/native-select";
import type { StudentSearchConditions } from "@/lib/company-students";
import { currentYearInTokyo, joinMonthDate, splitMonthDate, yearChoices } from "@/lib/form-values";
import type { Options } from "@/lib/options";

// ポップアップの中で持つ下書き。開始時期は、年と月の片方だけ選んだ状態も持てるよう、2つの文字で持つ
export type CompanyWorkConditionsDraft = {
  work_days_per_week: number | null;
  work_hours_per_day: number | null;
  duration_months: number | null;
  start_year: string;
  start_month: string;
  work_style: string | null;
  prefecture_id: number | null;
};

// 検索の条件 → 下書き
export function toCompanyWorkConditionsDraft(conditions: StudentSearchConditions): CompanyWorkConditionsDraft {
  const { year, month } = splitMonthDate(conditions.start_month);
  return {
    work_days_per_week: conditions.work_days_per_week,
    work_hours_per_day: conditions.work_hours_per_day,
    duration_months: conditions.duration_months,
    start_year: year,
    start_month: month,
    work_style: conditions.work_style,
    prefecture_id: conditions.prefecture_id,
  };
}

// 下書き → 検索の条件の稼働条件の部分。年と月の片方だけのときは、呼ぶ側が先に止める
export function fromCompanyWorkConditionsDraft(draft: CompanyWorkConditionsDraft) {
  return {
    work_days_per_week: draft.work_days_per_week,
    work_hours_per_day: draft.work_hours_per_day,
    duration_months: draft.duration_months,
    start_month: joinMonthDate(draft.start_year, draft.start_month),
    work_style: draft.work_style,
    prefecture_id: draft.prefecture_id,
  };
}

// 指定している条件の数（[稼働条件（2）] のボタンに出す）
export function countCompanyWorkConditions(draft: CompanyWorkConditionsDraft): number {
  return [
    draft.work_days_per_week !== null,
    draft.work_hours_per_day !== null,
    draft.duration_months !== null,
    draft.start_year !== "" || draft.start_month !== "",
    draft.work_style !== null,
    draft.prefecture_id !== null,
  ].filter(Boolean).length;
}

// 何も指定していない下書き（「この条件をクリア」）
export const EMPTY_COMPANY_WORK_CONDITIONS: CompanyWorkConditionsDraft = {
  work_days_per_week: null,
  work_hours_per_day: null,
  duration_months: null,
  start_year: "",
  start_month: "",
  work_style: null,
  prefecture_id: null,
};

type CompanySearchWorkConditionsProps = {
  options: Options;
  draft: CompanyWorkConditionsDraft;
  onChange: (draft: CompanyWorkConditionsDraft) => void;
  // 開始時期の確認で見つかったエラー（「開始時期は年と月の両方を選んでください」）
  startMonthErrors?: string[];
};

export function CompanySearchWorkConditions({
  options,
  draft,
  onChange,
  startMonthErrors,
}: CompanySearchWorkConditionsProps) {
  const { work_conditions: choices } = options;
  const currentYear = currentYearInTokyo();

  function update<K extends keyof CompanyWorkConditionsDraft>(key: K, value: CompanyWorkConditionsDraft[K]) {
    onChange({ ...draft, [key]: value });
  }

  return (
    <FieldGroup>
      {/* ボタンの数値は、選択肢の窓口（⑦）が返す稼働条件の数値（募集詳細編集と同じ） */}
      <ChoiceButtons
        legend="週の稼働日数"
        choices={choices.work_days_per_week.map((n) => ({ value: n, label: `週${n}日以上` }))}
        value={draft.work_days_per_week}
        onChange={(value) => update("work_days_per_week", value)}
      />
      <ChoiceButtons
        legend="1日の稼働時間"
        choices={choices.work_hours_per_day.map((n) => ({ value: n, label: `${n}時間以上` }))}
        value={draft.work_hours_per_day}
        onChange={(value) => update("work_hours_per_day", value)}
      />
      <ChoiceButtons
        legend="継続期間"
        choices={choices.duration_months.map((n) => ({ value: n, label: `${n}ヶ月以上` }))}
        value={draft.duration_months}
        onChange={(value) => update("duration_months", value)}
      />

      {/* 年と月の2つの選択欄。年の選択肢は、募集詳細編集と同じ1年前〜2年後 */}
      <MonthField
        id="search-start-year"
        label="開始時期"
        year={draft.start_year}
        month={draft.start_month}
        onYearChange={(value) => update("start_year", value)}
        onMonthChange={(value) => update("start_month", value)}
        years={yearChoices(currentYear - 1, currentYear + 2, draft.start_year)}
        errors={startMonthErrors}
        description="この月までに働き始められる学生が、条件に合います。今月より前の月を選ぶと、条件として使いません"
      />

      {/* 勤務形態：1つだけ選ぶ。学生がその勤務形態を「可能」にしていれば合う。表示名は ⑦ の enums.work_style */}
      <ChoiceButtons
        legend="勤務形態"
        choices={options.enums.work_style}
        value={draft.work_style}
        onChange={(value) => update("work_style", value)}
      />

      {/* 勤務地：1つだけ選ぶ。学生の出社できる都道府県に含まれれば合う */}
      <Field>
        <FieldLabel htmlFor="search-prefecture">勤務地</FieldLabel>
        <FieldDescription>勤務形態でフルリモートを選んでいるときは、勤務地は使いません</FieldDescription>
        <NativeSelect
          id="search-prefecture"
          value={draft.prefecture_id === null ? "" : String(draft.prefecture_id)}
          onChange={(event) => update("prefecture_id", event.target.value === "" ? null : Number(event.target.value))}
        >
          <NativeSelectOption value="">指定なし</NativeSelectOption>
          {options.masters.prefectures.map((prefecture) => (
            <NativeSelectOption key={prefecture.id} value={String(prefecture.id)}>
              {prefecture.name}
            </NativeSelectOption>
          ))}
        </NativeSelect>
      </Field>
    </FieldGroup>
  );
}
