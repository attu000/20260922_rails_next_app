// 入力欄の部品と、開閉するまとまり。募集詳細編集（C3）とマイページ（S1）で使い回す。
// 見出し・入力欄・文字数・エラーの組み立てを1か所にまとめる。
// 部品は、フォームの中ではなく、このファイルの一番上の段に置く
// （フォームの中で定義すると、描き直すたびに入力欄が作り直され、打っている途中でカーソルが外れるため）

import type { ReactNode } from "react";
import { AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { Field, FieldDescription, FieldError, FieldGroup, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { NativeSelect, NativeSelectOption } from "@/components/ui/native-select";
import { Textarea } from "@/components/ui/textarea";
import { MONTH_NUMBERS } from "@/lib/form-values";

// 項目ごとのエラー。Rails の 422 の errors と同じ形（例：{ title: ["募集タイトルを入力してください"] }）
export type FieldErrors = Record<string, string[]>;

// 文字数の上限。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）
export const SHORT_TEXT_MAX_LENGTH = 100;
export const LONG_TEXT_MAX_LENGTH = 2000;

// FieldError に渡す形に直す
export function toFieldErrorItems(messages: string[] | undefined) {
  return messages?.map((message) => ({ message }));
}

// 入力欄の部品が共通で受け取るもの。各フォームの textProps() で作って渡す
export type InputProps = {
  id: string;
  value: string;
  onChange: (value: string) => void;
  errors: string[] | undefined;
};

// 文字の入力欄（1行）
export function TextField({ id, value, onChange, errors, label }: InputProps & { label: string }) {
  return (
    <Field data-invalid={errors ? true : undefined}>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <Input
        id={id}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        aria-invalid={errors ? true : undefined}
      />
      <FieldDescription>
        {value.length}／{SHORT_TEXT_MAX_LENGTH}文字
      </FieldDescription>
      <FieldError errors={toFieldErrorItems(errors)} />
    </Field>
  );
}

// 文章の入力欄（複数行）。placeholder は、空欄のときに薄く出す文
export function LongTextField({
  id,
  value,
  onChange,
  errors,
  label,
  placeholder,
  description,
}: InputProps & { label: string; placeholder?: string; description?: string }) {
  return (
    <Field data-invalid={errors ? true : undefined}>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      {description && <FieldDescription>{description}</FieldDescription>}
      <Textarea
        id={id}
        rows={4}
        value={value}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
        aria-invalid={errors ? true : undefined}
      />
      <FieldDescription>
        {value.length}／{LONG_TEXT_MAX_LENGTH}文字
      </FieldDescription>
      <FieldError errors={toFieldErrorItems(errors)} />
    </Field>
  );
}

// 選択欄。選択肢と表示名は Rails が返したものだけを使う（API設計.md の 16-1-9）
export function SelectField({
  id,
  value,
  onChange,
  errors,
  label,
  choices,
  emptyLabel,
  description,
}: InputProps & {
  label: string;
  choices: { value: string; label: string }[];
  // 空欄の選択肢の表示。なければ空欄を選べない
  emptyLabel?: string;
  description?: string;
}) {
  return (
    <Field data-invalid={errors ? true : undefined}>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <NativeSelect
        id={id}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        aria-invalid={errors ? true : undefined}
      >
        {emptyLabel !== undefined && <NativeSelectOption value="">{emptyLabel}</NativeSelectOption>}
        {choices.map((choice) => (
          <NativeSelectOption key={choice.value} value={choice.value}>
            {choice.label}
          </NativeSelectOption>
        ))}
      </NativeSelect>
      {description && <FieldDescription>{description}</FieldDescription>}
      <FieldError errors={toFieldErrorItems(errors)} />
    </Field>
  );
}

// 年と月の2つの選択欄（「2026年 ▼」「10月 ▼」「から」）。募集と学生の開始時期で使う。
// 年の選択肢は、呼ぶ側が yearChoices（lib/form-values.ts）で作って渡す
export function MonthField({
  id,
  label,
  year,
  month,
  onYearChange,
  onMonthChange,
  years,
  errors,
  description,
}: {
  id: string;
  label: string;
  year: string;
  month: string;
  onYearChange: (value: string) => void;
  onMonthChange: (value: string) => void;
  years: string[];
  errors: string[] | undefined;
  description?: string;
}) {
  return (
    <Field data-invalid={errors ? true : undefined}>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <div className="flex items-center gap-2">
        <NativeSelect
          id={id}
          value={year}
          onChange={(event) => onYearChange(event.target.value)}
          aria-invalid={errors ? true : undefined}
        >
          <NativeSelectOption value="">―</NativeSelectOption>
          {years.map((choice) => (
            <NativeSelectOption key={choice} value={choice}>
              {choice}年
            </NativeSelectOption>
          ))}
        </NativeSelect>
        <NativeSelect
          aria-label={`${label}の月`}
          value={month}
          onChange={(event) => onMonthChange(event.target.value)}
          aria-invalid={errors ? true : undefined}
        >
          <NativeSelectOption value="">―</NativeSelectOption>
          {MONTH_NUMBERS.map((choice) => (
            <NativeSelectOption key={choice} value={choice}>
              {choice}月
            </NativeSelectOption>
          ))}
        </NativeSelect>
        <span className="text-sm">から</span>
      </div>
      {description && <FieldDescription>{description}</FieldDescription>}
      <FieldError errors={toFieldErrorItems(errors)} />
    </Field>
  );
}

// まとまり1つ分。四角い見出しの行（題名と一言、エラーがあれば「要確認」）と、押すと下に開く中身。
// 親の Accordion（multiple）の中に並べる。
// 閉じている間も中身は消さずに隠すだけにする（keepMounted）。職種の開閉などの状態を、閉じても覚えておくため
export function FormSection({
  value,
  title,
  hint,
  hasError,
  children,
}: {
  value: string;
  title: string;
  hint: string;
  hasError: boolean;
  children: ReactNode;
}) {
  return (
    <AccordionItem value={value} className="rounded-lg border">
      <AccordionTrigger className="items-center px-4 py-3 hover:no-underline">
        <span className="flex flex-col gap-0.5">
          <span className="text-base font-bold">{title}</span>
          <span className="text-xs font-normal text-muted-foreground">{hint}</span>
        </span>
        {hasError && <span className="mr-2 ml-auto text-xs text-destructive">要確認</span>}
      </AccordionTrigger>
      <AccordionContent keepMounted className="px-4 pt-2 pb-4">
        <FieldGroup>{children}</FieldGroup>
      </AccordionContent>
    </AccordionItem>
  );
}
