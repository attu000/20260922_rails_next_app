"use client";

// 企業プロフィール編集（C1）の入力フォーム。詳しくは design/designs/ページ設計.md の 6-5 C1、API設計.md の 16-3 ⑦⑧⑨⑩。
// 開いたら ⑦ 選択肢と ⑧ 自社のプロフィールを SWR で取り、保存で ⑨ を送る。アイコンを選んでいたら、⑨ の成功後に ⑩ を続けて送る。
// 必須は会社名だけ（その他決め事.md の 5-9）。見た目は shadcn/ui の部品で、最低限だけそろえている。
// 業界〜どんな会社かの欄は、新規登録と共通の部品（components/company-info-fields.tsx）

import { useEffect, useRef, useState, type FormEvent } from "react";
import { CompanyInfoFields, validateCompanyInfo, type CompanyInfoValues } from "@/components/company-info-fields";
import { LabelText, RequiredNote, toFieldErrorItems, type FieldErrors } from "@/components/form-fields";
import { IconField, uploadIcon, useIconPicker, validateIconFile } from "@/components/icon-field";
import { useRedirectIfUnauthorized, useRefreshMe } from "@/components/member-only";
import { PageTitle } from "@/components/page-title";
import { Button } from "@/components/ui/button";
import { Field, FieldError, FieldGroup, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { ApiError, apiFetch, useApi } from "@/lib/api";
import { useOptions } from "@/lib/options";

// ⑧⑨ の返事の形。Rails の app/views/api/company/profiles/show.json.jbuilder と同じ
type CompanyProfile = {
  name: string;
  industry_ids: number[];
  business_type_ids: number[];
  employee_size: string | null;
  business_description: string | null;
  about: string | null;
  icon_url: string | null;
};

// フォームが持つ値。空欄は null ではなく "" で持つ（入力欄にそのまま入れるため）
type FormValues = CompanyInfoValues & {
  name: string;
};

// 会社名の長さの決まり。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）
const NAME_MAX_LENGTH = 100;

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

function toFormValues(profile: CompanyProfile): FormValues {
  return {
    name: profile.name,
    industry_ids: profile.industry_ids,
    business_type_ids: profile.business_type_ids,
    employee_size: profile.employee_size ?? "",
    business_description: profile.business_description ?? "",
    about: profile.about ?? "",
  };
}

// その場で分かる確認だけを行う（17-3-2）。Rails も同じ確認をするので、ここをすり抜けても守られる。
// 文言は Rails と同じにする
function validateOnScreen(values: FormValues, iconFile: File | null): FieldErrors {
  // 業界〜どんな会社かの確認は、新規登録と共通
  const errors: FieldErrors = validateCompanyInfo(values);
  if (values.name.trim() === "") {
    errors.name = ["会社名を入力してください"];
  } else if (values.name.length > NAME_MAX_LENGTH) {
    errors.name = [`会社名は${NAME_MAX_LENGTH}文字以内で入力してください`];
  }
  const iconErrors = validateIconFile(iconFile);
  if (iconErrors) {
    errors.icon = iconErrors;
  }
  return errors;
}

export function CompanyProfileForm() {
  const { options, failed: optionsFailed } = useOptions();
  const refreshMe = useRefreshMe();
  const redirectIfUnauthorized = useRedirectIfUnauthorized();

  const [values, setValues] = useState<FormValues | null>(null);
  // 保存済みのアイコンの URL と、選んだ（まだ送っていない）ファイル・プレビュー（components/icon-field.tsx）
  const [currentIconUrl, setCurrentIconUrl] = useState<string | null>(null);
  const iconPicker = useIconPicker();

  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  // 画面の上に出す一言
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  // 増えたら、最初のエラーの項目まで画面を動かす（17-3-2）
  const [scrollToErrorRequest, setScrollToErrorRequest] = useState(0);

  const formRef = useRef<HTMLFormElement>(null);

  // 開いたら ⑧ 自社のプロフィールを取る。401 は共通の枠がログイン画面へ移す
  const {
    data: profile,
    error: profileError,
    isValidating: profileValidating,
    mutate: mutateProfile,
  } = useApi<CompanyProfile>("/api/company/profile");

  // 入力欄の最初の値は、最新を取り終えてから1回だけ入れる。
  // SWR は前に開いたときの内容を覚えていて、まずそれを出してから裏で取り直すので、
  // 取り直しが終わる前に入れると、古い内容が入力欄に残ってしまうため。
  // 描いている途中で値を入れるのは、React の「前の描画から情報を引き継ぐ」書き方（values が null の間だけ動く）
  if (values === null && profile && !profileValidating) {
    setValues(toFormValues(profile));
    setCurrentIconUrl(profile.icon_url);
  }

  // 最初のエラーの項目まで画面を動かす
  useEffect(() => {
    if (scrollToErrorRequest === 0) return;
    formRef.current
      ?.querySelector('[data-slot="field-error"]')
      ?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [scrollToErrorRequest]);

  function updateValue<K extends keyof FormValues>(key: K, value: FormValues[K]) {
    setValues((current) => (current ? { ...current, [key]: value } : current));
    setSaved(false);
  }

  function showErrors(errors: FieldErrors) {
    setFieldErrors(errors);
    setScrollToErrorRequest((count) => count + 1);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で送る
    event.preventDefault();
    // 2回押しても、1回だけ送る。ボタンは押せなくしない（17-3-2）
    if (!values || saving) return;

    setMessage(null);
    setSaved(false);
    const screenErrors = validateOnScreen(values, iconPicker.file);
    if (Object.keys(screenErrors).length > 0) {
      setMessage("入力内容を確認してください");
      showErrors(screenErrors);
      return;
    }
    setFieldErrors({});
    setSaving(true);

    try {
      // ① 本体を保存する（⑨）。フォームの全項目を送る。人数が空欄なら null
      const savedProfile = await apiFetch<CompanyProfile>("/api/company/profile", {
        method: "PATCH",
        body: { ...values, employee_size: values.employee_size === "" ? null : values.employee_size },
      });
      setValues(toFormValues(savedProfile));
      // SWR が覚えている中身も、保存後の内容に差し替える（取り直しはしない）
      await mutateProfile(savedProfile, { revalidate: false });

      // ② アイコンを選んでいたら、続けて送る（⑩。⑨ の成功後に送る決まり）
      let iconFailed = false;
      if (iconPicker.file) {
        try {
          const iconUrl = await uploadIcon("/api/company/profile/icon", iconPicker.file);
          setCurrentIconUrl(iconUrl);
          await mutateProfile({ ...savedProfile, icon_url: iconUrl }, { revalidate: false });
          iconPicker.clear();
        } catch (error) {
          if (redirectIfUnauthorized(error)) return;
          // 本体の保存は取り消さない
          iconFailed = true;
          setMessage("会社情報は保存しましたが、アイコンは保存できませんでした");
          if (error instanceof ApiError && error.errors) showErrors(error.errors);
        }
      }

      // ヘッダーの会社名とアイコンを新しくする
      await refreshMe();
      if (!iconFailed) setSaved(true);
    } catch (error) {
      if (redirectIfUnauthorized(error)) return;
      if (error instanceof ApiError && error.status === 422 && error.errors) {
        showErrors(error.errors);
      }
      setMessage(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
    } finally {
      setSaving(false);
    }
  }

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  // ⑧ が取れなかった。401 のときは共通の枠がログイン画面へ移すので、読み込み中のままにする
  if (!values && profileError && profileError.status !== 401) {
    return <p className="text-sm text-destructive">{profileError.message}</p>;
  }

  if (!options || !values) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <PageTitle>企業プロフィール編集</PageTitle>
        <RequiredNote />
      </div>

      {message && <p className="text-sm text-destructive">{message}</p>}

      {/* noValidate：ブラウザの入力チェックを止め、その場での確認と Rails の確認の文言にそろえる */}
      <form ref={formRef} onSubmit={handleSubmit} noValidate className="max-w-2xl">
        <FieldGroup>
          <Field data-invalid={fieldErrors.name ? true : undefined}>
            <FieldLabel htmlFor="name">
              <LabelText label="会社名" required />
            </FieldLabel>
            <Input
              id="name"
              value={values.name}
              onChange={(event) => updateValue("name", event.target.value)}
              aria-invalid={fieldErrors.name ? true : undefined}
            />
            <FieldError errors={toFieldErrorItems(fieldErrors.name)} />
          </Field>

          <CompanyInfoFields
            values={values}
            onChange={(change) => {
              setValues((current) => (current ? { ...current, ...change } : current));
              setSaved(false);
            }}
            errors={fieldErrors}
            options={options}
          />

          <IconField
            picker={iconPicker}
            currentUrl={currentIconUrl}
            name={values.name}
            errors={fieldErrors.icon}
            onFileChange={() => setSaved(false)}
          />

          <div className="flex items-center gap-4">
            <Button type="submit">{saving ? "保存中…" : "保存"}</Button>
            {saved && <p className="text-sm text-muted-foreground">保存しました</p>}
          </div>
        </FieldGroup>
      </form>
    </div>
  );
}
