// 新規登録のステップ1（アカウント）の入力欄、その場の確認、④ メールアドレスの確認。
// 企業（C9）と学生（S9）の新規登録で使い回す（design/designs/ページ設計.md の 6-5 C9・6-6 S9、API設計.md の 16-3 ④）。
// 守りは Rails にある（最後の「登録する」で、Rails が改めて全部確かめる）。ここでの確認は、全部入力した後にやり直しにならないためだけ。
// 利用規約・プライバシーポリシーへの同意のチェックは【仕上げ】で足す

import { LabelText, SHORT_TEXT_MAX_LENGTH, toFieldErrorItems, type FieldErrors } from "@/components/form-fields";
import { Field, FieldDescription, FieldError, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { ApiError, apiFetch } from "@/lib/api";

// パスワードの長さの下限。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）
const PASSWORD_MIN_LENGTH = 8;

// ステップ1の値。名前は、企業なら会社名、学生なら氏名
export type AccountValues = {
  email: string;
  password: string;
  password_confirmation: string;
  name: string;
};

// 何も入れていない値（新規登録の最初）
export const EMPTY_ACCOUNT: AccountValues = {
  email: "",
  password: "",
  password_confirmation: "",
  name: "",
};

// ステップ1の項目の名前。Rails の 422 の誤りが、どのステップの項目かを見分けるのに使う（16-3 ⑤）
export const ACCOUNT_KEYS: string[] = Object.keys(EMPTY_ACCOUNT);

// その場で分かる確認だけを行う（権限_バリデーション.md の 17-3-2）。文言は Rails と同じにする。
// nameLabel：名前の項目名（「会社名」か「氏名」）
export function validateAccountOnScreen(values: AccountValues, nameLabel: string): FieldErrors {
  const errors: FieldErrors = {};
  if (values.email.trim() === "") {
    errors.email = ["メールアドレスを入力してください"];
  }
  if (values.password === "") {
    errors.password = ["パスワードを入力してください"];
  } else if (values.password.length < PASSWORD_MIN_LENGTH) {
    errors.password = [`パスワードは${PASSWORD_MIN_LENGTH}文字以上で入力してください`];
  }
  if (values.password !== "" && values.password_confirmation !== values.password) {
    errors.password_confirmation = ["パスワード（確認）とパスワードの入力が一致しません"];
  }
  if (values.name.trim() === "") {
    errors.name = [`${nameLabel}を入力してください`];
  } else if (values.name.length > SHORT_TEXT_MAX_LENGTH) {
    errors.name = [`${nameLabel}は${SHORT_TEXT_MAX_LENGTH}文字以内で入力してください`];
  }
  return errors;
}

// ④ メールアドレスが使えるかを Rails に確かめる。使えるなら undefined、使えなければメールアドレスの誤り（Rails の文そのまま）。
// 形式・登録済みの判定は Rails が行う（大文字や前後の空白をそろえてから比べる）。
// 422 以外の失敗（通信の失敗など）は、そのまま投げる（呼んだ側が一言を出す）
export async function checkEmail(email: string): Promise<string[] | undefined> {
  try {
    await apiFetch<null>("/api/email_checks", { method: "POST", body: { email } });
    return undefined;
  } catch (error) {
    if (error instanceof ApiError && error.status === 422 && error.errors) {
      return error.errors.email ?? [error.message];
    }
    throw error;
  }
}

type SignupAccountFieldsProps = {
  values: AccountValues;
  onChange: (key: keyof AccountValues, value: string) => void;
  errors: FieldErrors;
  // 名前の項目名（「会社名」か「氏名」）
  nameLabel: string;
  // 名前の欄の、ブラウザの自動入力の種類（会社名なら "organization"、氏名なら "name"）
  nameAutoComplete: "organization" | "name";
};

// ステップ1の入力欄：メールアドレス、パスワード、パスワード（確認）、名前。4つとも必須（項目名の横に赤い「＊」。PR231）
export function SignupAccountFields({ values, onChange, errors, nameLabel, nameAutoComplete }: SignupAccountFieldsProps) {
  // 1つの欄の組み立て（見出し・入力欄・説明・エラー）
  function textField(
    key: keyof AccountValues,
    label: string,
    type: "email" | "password" | "text",
    autoComplete: string,
    description?: string,
  ) {
    return (
      <Field data-invalid={errors[key] ? true : undefined}>
        <FieldLabel htmlFor={key}>
          <LabelText label={label} required />
        </FieldLabel>
        <Input
          id={key}
          type={type}
          autoComplete={autoComplete}
          value={values[key]}
          onChange={(event) => onChange(key, event.target.value)}
          aria-invalid={errors[key] ? true : undefined}
        />
        {description && <FieldDescription>{description}</FieldDescription>}
        <FieldError errors={toFieldErrorItems(errors[key])} />
      </Field>
    );
  }

  return (
    <>
      {textField("email", "メールアドレス", "email", "email")}
      {textField("password", "パスワード", "password", "new-password", `${PASSWORD_MIN_LENGTH}文字以上`)}
      {textField("password_confirmation", "パスワード（確認）", "password", "new-password")}
      {textField("name", nameLabel, "text", nameAutoComplete)}
    </>
  );
}
