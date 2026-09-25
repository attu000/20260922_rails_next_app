"use client";

// 企業プロフィール編集（C1）の入力フォーム。詳しくは design/designs/ページ設計.md の 6-5 C1、API設計.md の 16-3 ⑦⑧⑨⑩。
// 開いたら ⑦ 選択肢と ⑧ 自社のプロフィールを取り、保存で ⑨ を送る。アイコンを選んでいたら、⑨ の成功後に ⑩ を続けて送る。
// 必須は会社名だけ（その他決め事.md の 5-9）。見た目は shadcn/ui の部品で、最低限だけそろえている

import { useEffect, useRef, useState, type ChangeEvent, type FormEvent } from "react";
import { MasterCheckboxGroup } from "@/components/master-checkbox-group";
import { useRedirectIfUnauthorized, useRefreshMe } from "@/components/member-only";
import { PageTitle } from "@/components/page-title";
import { ProfileIcon } from "@/components/profile-icon";
import { Button } from "@/components/ui/button";
import { Field, FieldDescription, FieldError, FieldGroup, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { NativeSelect, NativeSelectOption } from "@/components/ui/native-select";
import { Textarea } from "@/components/ui/textarea";
import { ApiError, apiFetch } from "@/lib/api";
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
type FormValues = {
  name: string;
  industry_ids: number[];
  business_type_ids: number[];
  employee_size: string;
  business_description: string;
  about: string;
};

// 項目ごとのエラー。Rails の 422 の errors と同じ形（例：{ name: ["会社名を入力してください"] }）
type FieldErrors = Record<string, string[]>;

// 形式と長さの決まり。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4、技術構成.md の 9-3）
const NAME_MAX_LENGTH = 100;
const TEXT_MAX_LENGTH = 2000;
const ICON_CONTENT_TYPES = ["image/png", "image/jpeg", "image/webp"];
const ICON_MAX_BYTES = 2 * 1024 * 1024;

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
  const errors: FieldErrors = {};
  if (values.name.trim() === "") {
    errors.name = ["会社名を入力してください"];
  } else if (values.name.length > NAME_MAX_LENGTH) {
    errors.name = [`会社名は${NAME_MAX_LENGTH}文字以内で入力してください`];
  }
  if (values.business_description.length > TEXT_MAX_LENGTH) {
    errors.business_description = [`事業内容は${TEXT_MAX_LENGTH}文字以内で入力してください`];
  }
  if (values.about.length > TEXT_MAX_LENGTH) {
    errors.about = [`どんな会社かは${TEXT_MAX_LENGTH}文字以内で入力してください`];
  }
  if (iconFile) {
    const iconErrors: string[] = [];
    if (!ICON_CONTENT_TYPES.includes(iconFile.type)) {
      iconErrors.push("アイコンはPNG・JPEG・WebPのいずれかにしてください");
    }
    if (iconFile.size > ICON_MAX_BYTES) {
      iconErrors.push("アイコンは2MB以下にしてください");
    }
    if (iconErrors.length > 0) {
      errors.icon = iconErrors;
    }
  }
  return errors;
}

// FieldError に渡す形に直す
function toFieldErrorItems(messages: string[] | undefined) {
  return messages?.map((message) => ({ message }));
}

export function CompanyProfileForm() {
  const { options, failed: optionsFailed } = useOptions();
  const refreshMe = useRefreshMe();
  const redirectIfUnauthorized = useRedirectIfUnauthorized();

  const [values, setValues] = useState<FormValues | null>(null);
  // 保存済みのアイコンの URL と、選んだ（まだ送っていない）ファイル、そのプレビュー
  const [currentIconUrl, setCurrentIconUrl] = useState<string | null>(null);
  const [iconFile, setIconFile] = useState<File | null>(null);
  const [iconPreviewUrl, setIconPreviewUrl] = useState<string | null>(null);

  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  // 画面の上に出す一言
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  // 増えたら、最初のエラーの項目まで画面を動かす（17-3-2）
  const [scrollToErrorRequest, setScrollToErrorRequest] = useState(0);

  const formRef = useRef<HTMLFormElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // 開いたら ⑧ 自社のプロフィールを取る
  useEffect(() => {
    // 画面を離れた後に返事が来たときは、何もしない
    let active = true;

    apiFetch<CompanyProfile>("/api/company/profile")
      .then((profile) => {
        if (!active) return;
        setValues(toFormValues(profile));
        setCurrentIconUrl(profile.icon_url);
      })
      .catch((error: unknown) => {
        if (!active || redirectIfUnauthorized(error)) return;
        setMessage(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
      });

    return () => {
      active = false;
    };
  }, [redirectIfUnauthorized]);

  // 最初のエラーの項目まで画面を動かす
  useEffect(() => {
    if (scrollToErrorRequest === 0) return;
    formRef.current
      ?.querySelector('[data-slot="field-error"]')
      ?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [scrollToErrorRequest]);

  // プレビューの URL は、使い終わったら（別のファイルを選んだ、画面を離れた）ブラウザに返す
  useEffect(() => {
    return () => {
      if (iconPreviewUrl) URL.revokeObjectURL(iconPreviewUrl);
    };
  }, [iconPreviewUrl]);

  function updateValue<K extends keyof FormValues>(key: K, value: FormValues[K]) {
    setValues((current) => (current ? { ...current, [key]: value } : current));
    setSaved(false);
  }

  function handleIconChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0] ?? null;
    setIconFile(file);
    // 保存を押すまで Rails には送らない。ブラウザの中だけでプレビューを出す
    setIconPreviewUrl(file ? URL.createObjectURL(file) : null);
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
    const screenErrors = validateOnScreen(values, iconFile);
    if (Object.keys(screenErrors).length > 0) {
      setMessage("入力内容を確認してください");
      showErrors(screenErrors);
      return;
    }
    setFieldErrors({});
    setSaving(true);

    try {
      // ① 本体を保存する（⑨）。フォームの全項目を送る。人数が空欄なら null
      const profile = await apiFetch<CompanyProfile>("/api/company/profile", {
        method: "PATCH",
        body: { ...values, employee_size: values.employee_size === "" ? null : values.employee_size },
      });
      setValues(toFormValues(profile));

      // ② アイコンを選んでいたら、続けて送る（⑩。⑨ の成功後に送る決まり）
      let iconFailed = false;
      if (iconFile) {
        const formData = new FormData();
        formData.append("icon", iconFile);
        try {
          const result = await apiFetch<{ icon_url: string | null }>("/api/company/profile/icon", {
            method: "POST",
            body: formData,
          });
          setCurrentIconUrl(result.icon_url);
          setIconFile(null);
          setIconPreviewUrl(null);
          if (fileInputRef.current) fileInputRef.current.value = "";
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

  if (!options || !values) {
    // 読み込みに失敗したときは、上に出す一言を出す
    return <p className="text-sm text-muted-foreground">{message ?? "読み込み中…"}</p>;
  }

  return (
    <div className="space-y-6">
      <PageTitle>企業プロフィール編集</PageTitle>

      {message && <p className="text-sm text-destructive">{message}</p>}

      {/* noValidate：ブラウザの入力チェックを止め、その場での確認と Rails の確認の文言にそろえる */}
      <form ref={formRef} onSubmit={handleSubmit} noValidate className="max-w-2xl">
        <FieldGroup>
          <Field data-invalid={fieldErrors.name ? true : undefined}>
            <FieldLabel htmlFor="name">会社名（必須）</FieldLabel>
            <Input
              id="name"
              value={values.name}
              onChange={(event) => updateValue("name", event.target.value)}
              aria-invalid={fieldErrors.name ? true : undefined}
            />
            <FieldError errors={toFieldErrorItems(fieldErrors.name)} />
          </Field>

          <MasterCheckboxGroup
            name="industry"
            legend="業界"
            rows={options.masters.industries}
            selectedIds={values.industry_ids}
            onChange={(ids) => updateValue("industry_ids", ids)}
            errors={fieldErrors.industry_ids}
          />

          <MasterCheckboxGroup
            name="business-type"
            legend="事業形態"
            rows={options.masters.business_types}
            selectedIds={values.business_type_ids}
            onChange={(ids) => updateValue("business_type_ids", ids)}
            errors={fieldErrors.business_type_ids}
          />

          <Field data-invalid={fieldErrors.business_description ? true : undefined}>
            <FieldLabel htmlFor="business_description">事業内容</FieldLabel>
            <Textarea
              id="business_description"
              rows={4}
              value={values.business_description}
              onChange={(event) => updateValue("business_description", event.target.value)}
              aria-invalid={fieldErrors.business_description ? true : undefined}
            />
            <FieldDescription>
              {values.business_description.length}／{TEXT_MAX_LENGTH}文字
            </FieldDescription>
            <FieldError errors={toFieldErrorItems(fieldErrors.business_description)} />
          </Field>

          <Field data-invalid={fieldErrors.employee_size ? true : undefined}>
            <FieldLabel htmlFor="employee_size">人数</FieldLabel>
            <NativeSelect
              id="employee_size"
              value={values.employee_size}
              onChange={(event) => updateValue("employee_size", event.target.value)}
              aria-invalid={fieldErrors.employee_size ? true : undefined}
            >
              <NativeSelectOption value="">選択してください</NativeSelectOption>
              {/* 選択肢と表示名は Rails が返したものだけを使う（16-1-9） */}
              {options.enums.employee_size.map((option) => (
                <NativeSelectOption key={option.value} value={option.value}>
                  {option.label}
                </NativeSelectOption>
              ))}
            </NativeSelect>
            <FieldError errors={toFieldErrorItems(fieldErrors.employee_size)} />
          </Field>

          <Field data-invalid={fieldErrors.about ? true : undefined}>
            <FieldLabel htmlFor="about">どんな会社か</FieldLabel>
            <Textarea
              id="about"
              rows={4}
              value={values.about}
              onChange={(event) => updateValue("about", event.target.value)}
              aria-invalid={fieldErrors.about ? true : undefined}
            />
            <FieldDescription>
              {values.about.length}／{TEXT_MAX_LENGTH}文字
            </FieldDescription>
            <FieldError errors={toFieldErrorItems(fieldErrors.about)} />
          </Field>

          <Field data-invalid={fieldErrors.icon ? true : undefined}>
            <FieldLabel htmlFor="icon">アイコン</FieldLabel>
            <div className="flex items-center gap-4">
              <ProfileIcon src={iconPreviewUrl ?? currentIconUrl} name={values.name} size="lg" />
              <input
                ref={fileInputRef}
                id="icon"
                type="file"
                accept={ICON_CONTENT_TYPES.join(",")}
                onChange={handleIconChange}
                aria-invalid={fieldErrors.icon ? true : undefined}
                className="text-sm"
              />
            </div>
            <FieldDescription>PNG・JPEG・WebP、2MBまで。保存を押すと登録されます</FieldDescription>
            <FieldError errors={toFieldErrorItems(fieldErrors.icon)} />
          </Field>

          <div className="flex items-center gap-4">
            <Button type="submit">{saving ? "保存中…" : "保存"}</Button>
            {saved && <p className="text-sm text-muted-foreground">保存しました</p>}
          </div>
        </FieldGroup>
      </form>
    </div>
  );
}
