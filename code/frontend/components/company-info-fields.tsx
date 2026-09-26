// 会社情報の入力欄（業界・事業形態・事業内容・人数・どんな会社か）と、その場の確認。
// 企業プロフィール編集（C1）と、企業の新規登録（C9）のステップ2で使い回す
// （design/designs/ページ設計.md の 6-5 C1・C9、API設計.md の 16-3 ⑨⑤）。
// 会社名とアイコンは、新規登録ではステップ1と最後に分かれて置かれるので、この部品には入れない

import { LONG_TEXT_MAX_LENGTH, toFieldErrorItems, type FieldErrors } from "@/components/form-fields";
import { MasterCheckboxGroup } from "@/components/master-checkbox-group";
import { Field, FieldDescription, FieldError, FieldLabel } from "@/components/ui/field";
import { NativeSelect, NativeSelectOption } from "@/components/ui/native-select";
import { Textarea } from "@/components/ui/textarea";
import type { Options } from "@/lib/options";

// 会社情報の値。空欄は null ではなく "" で持つ（入力欄にそのまま入れるため）
export type CompanyInfoValues = {
  industry_ids: number[];
  business_type_ids: number[];
  employee_size: string;
  business_description: string;
  about: string;
};

// 何も入れていない値（新規登録の最初）
export const EMPTY_COMPANY_INFO: CompanyInfoValues = {
  industry_ids: [],
  business_type_ids: [],
  employee_size: "",
  business_description: "",
  about: "",
};

// その場で分かる確認だけを行う（権限_バリデーション.md の 17-3-2）。Rails も同じ確認をするので、ここをすり抜けても守られる。
// 文言は Rails と同じにする
export function validateCompanyInfo(values: CompanyInfoValues): FieldErrors {
  const errors: FieldErrors = {};
  if (values.business_description.length > LONG_TEXT_MAX_LENGTH) {
    errors.business_description = [`事業内容は${LONG_TEXT_MAX_LENGTH}文字以内で入力してください`];
  }
  if (values.about.length > LONG_TEXT_MAX_LENGTH) {
    errors.about = [`どんな会社かは${LONG_TEXT_MAX_LENGTH}文字以内で入力してください`];
  }
  return errors;
}

type CompanyInfoFieldsProps = {
  values: CompanyInfoValues;
  // 変えた項目と値の組（例：{ about: "…" }）を渡す。使う側は、自分の値にそれを重ねる
  onChange: (change: Partial<CompanyInfoValues>) => void;
  errors: FieldErrors;
  options: Options;
};

export function CompanyInfoFields({ values, onChange, errors, options }: CompanyInfoFieldsProps) {
  return (
    <>
      <MasterCheckboxGroup
        name="industry"
        legend="業界"
        rows={options.masters.industries}
        selectedIds={values.industry_ids}
        onChange={(ids) => onChange({ industry_ids: ids })}
        errors={errors.industry_ids}
      />

      <MasterCheckboxGroup
        name="business-type"
        legend="事業形態"
        rows={options.masters.business_types}
        selectedIds={values.business_type_ids}
        onChange={(ids) => onChange({ business_type_ids: ids })}
        errors={errors.business_type_ids}
      />

      <Field data-invalid={errors.business_description ? true : undefined}>
        <FieldLabel htmlFor="business_description">事業内容</FieldLabel>
        <Textarea
          id="business_description"
          rows={4}
          value={values.business_description}
          onChange={(event) => onChange({ business_description: event.target.value })}
          aria-invalid={errors.business_description ? true : undefined}
        />
        <FieldDescription>
          {values.business_description.length}／{LONG_TEXT_MAX_LENGTH}文字
        </FieldDescription>
        <FieldError errors={toFieldErrorItems(errors.business_description)} />
      </Field>

      <Field data-invalid={errors.employee_size ? true : undefined}>
        <FieldLabel htmlFor="employee_size">人数</FieldLabel>
        <NativeSelect
          id="employee_size"
          value={values.employee_size}
          onChange={(event) => onChange({ employee_size: event.target.value })}
          aria-invalid={errors.employee_size ? true : undefined}
        >
          <NativeSelectOption value="">選択してください</NativeSelectOption>
          {/* 選択肢と表示名は Rails が返したものだけを使う（16-1-9） */}
          {options.enums.employee_size.map((option) => (
            <NativeSelectOption key={option.value} value={option.value}>
              {option.label}
            </NativeSelectOption>
          ))}
        </NativeSelect>
        <FieldError errors={toFieldErrorItems(errors.employee_size)} />
      </Field>

      <Field data-invalid={errors.about ? true : undefined}>
        <FieldLabel htmlFor="about">どんな会社か</FieldLabel>
        <Textarea
          id="about"
          rows={4}
          value={values.about}
          onChange={(event) => onChange({ about: event.target.value })}
          aria-invalid={errors.about ? true : undefined}
        />
        <FieldDescription>
          {values.about.length}／{LONG_TEXT_MAX_LENGTH}文字
        </FieldDescription>
        <FieldError errors={toFieldErrorItems(errors.about)} />
      </Field>
    </>
  );
}
