"use client";

// 企業の新規登録（C9）の中身。詳しくは design/designs/ページ設計.md の 6-5 C9、API設計.md の 16-3 ④⑤⑩。
// ステップ1 アカウント → ステップ2 会社情報 の2ステップ。入力は画面の中だけで持ち、最後の「登録する」で ⑤ にまとめて送る
// （途中でやめた人のデータは残らない。途中で読み込み直すと、入力は消える）。
// 登録できたら Rails が自動でログインした状態にするので、アイコンを選んでいれば ⑩ に続けて送り、企業のホーム（募集一覧）へ移る。
// 必須はステップ1だけ。ステップ2は空欄のままでも登録できる（権限_バリデーション.md の 17-3-5）。
// 守りは Rails にある。画面側の確認は、送る手間を省くためだけ。
// 利用規約・プライバシーポリシーへの同意と、進み具合の表示（「1／2」）は【仕上げ】で足す

import { useEffect, useRef, useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  CompanyInfoFields,
  EMPTY_COMPANY_INFO,
  validateCompanyInfo,
  type CompanyInfoValues,
} from "@/components/company-info-fields";
import { RequiredNote, type FieldErrors } from "@/components/form-fields";
import { IconField, uploadIcon, useIconPicker, validateIconFile } from "@/components/icon-field";
import { PageTitle } from "@/components/page-title";
import {
  ACCOUNT_KEYS,
  checkEmail,
  EMPTY_ACCOUNT,
  SignupAccountFields,
  validateAccountOnScreen,
  type AccountValues,
} from "@/components/signup-account-fields";
import { Button, buttonVariants } from "@/components/ui/button";
import { FieldDescription, FieldGroup } from "@/components/ui/field";
import { ApiError, apiFetch } from "@/lib/api";
import { homePathFor, loginPathFor, type Me } from "@/lib/auth";
import { useOptions } from "@/lib/options";

// 名前の項目名（Rails の company_profile.name と同じ）
const NAME_LABEL = "会社名";

// 入力に誤りがあるときに、画面の上に出す一言（Rails の 422 と同じ）
const INVALID_MESSAGE = "入力内容を確認してください";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// ステップ1（アカウント）かステップ2（会社情報）か
type Step = 1 | 2;

export function CompanySignupForm() {
  const router = useRouter();
  const { options, failed: optionsFailed } = useOptions();

  const [step, setStep] = useState<Step>(1);
  // ステップ1とステップ2の値。ステップを行き来しても消えない
  const [account, setAccount] = useState<AccountValues>(EMPTY_ACCOUNT);
  const [info, setInfo] = useState<CompanyInfoValues>(EMPTY_COMPANY_INFO);
  // 選んだ（まだ送っていない）アイコン（components/icon-field.tsx）
  const iconPicker = useIconPicker();

  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  // 画面の上に出す一言
  const [message, setMessage] = useState<string | null>(null);
  // 送っている途中か。2回押しても、1回だけ送る。ボタンは押せなくしない（17-3-2）
  const [submitting, setSubmitting] = useState(false);
  // 登録はできたが、アイコンだけ保存できなかった（PR229）
  const [iconFailed, setIconFailed] = useState(false);
  // 増えたら、最初のエラーの項目まで画面を動かす（17-3-2）
  const [scrollToErrorRequest, setScrollToErrorRequest] = useState(0);

  const formRef = useRef<HTMLFormElement>(null);

  // 最初のエラーの項目まで画面を動かす（会社情報の編集画面と同じ）
  useEffect(() => {
    if (scrollToErrorRequest === 0) return;
    formRef.current
      ?.querySelector('[data-slot="field-error"]')
      ?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [scrollToErrorRequest]);

  function showErrors(errors: FieldErrors) {
    setFieldErrors(errors);
    setMessage(INVALID_MESSAGE);
    setScrollToErrorRequest((count) => count + 1);
  }

  function goToStep(next: Step) {
    setStep(next);
    setMessage(null);
    // 次のステップは、画面の上から見せる
    window.scrollTo({ top: 0 });
  }

  // ステップ1の「次へ」：その場の確認 → ④ メールアドレスの確認 → ステップ2へ
  async function handleNext(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で進める
    event.preventDefault();
    if (submitting) return;

    const screenErrors = validateAccountOnScreen(account, NAME_LABEL);
    if (Object.keys(screenErrors).length > 0) {
      showErrors(screenErrors);
      return;
    }
    setSubmitting(true);
    try {
      // 全部入力した後にやり直しにならないよう、ここでメールアドレスが使えるかを確かめる（ページ設計.md の C9）
      const emailErrors = await checkEmail(account.email);
      if (emailErrors) {
        showErrors({ email: emailErrors });
        return;
      }
      setFieldErrors({});
      goToStep(2);
    } catch (error) {
      setMessage(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
    } finally {
      setSubmitting(false);
    }
  }

  // ステップ2の「登録する」：その場の確認 → ⑤ 登録（自動でログイン）→ ⑩ アイコン → 企業のホームへ
  async function handleRegister(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (submitting) return;

    const screenErrors = validateCompanyInfo(info);
    const iconErrors = validateIconFile(iconPicker.file);
    if (iconErrors) screenErrors.icon = iconErrors;
    if (Object.keys(screenErrors).length > 0) {
      showErrors(screenErrors);
      return;
    }
    setSubmitting(true);
    setMessage(null);

    try {
      // ① 全ステップの値をまとめて送る（⑤）。人数が空欄なら null。返事は形A（ログインした人）
      await apiFetch<Me>("/api/company_registrations", {
        method: "POST",
        body: { ...account, ...info, employee_size: info.employee_size === "" ? null : info.employee_size },
      });
    } catch (error) {
      // 入力の誤り（422）なら、誤りのある項目を含む最初のステップに戻して出す（16-3 ⑤）。
      // 例：その間にほかの人が同じメールアドレスで登録した → ステップ1のメールアドレスの欄に出る
      if (error instanceof ApiError && error.status === 422 && error.errors) {
        const errors = error.errors;
        if (Object.keys(errors).some((key) => ACCOUNT_KEYS.includes(key))) goToStep(1);
        showErrors(errors);
      } else {
        setMessage(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
      }
      setSubmitting(false);
      return;
    }

    // ② 登録できた（ログインした状態）。アイコンを選んでいたら、続けて送る（⑩。登録の成功後に送る決まり）
    if (iconPicker.file) {
      try {
        await uploadIcon("/api/company/profile/icon", iconPicker.file);
      } catch {
        // 登録は取り消さない。一言と「募集一覧へ進む」を出し、利用者が押して進む（PR229）
        setIconFailed(true);
        setSubmitting(false);
        return;
      }
    }

    // ③ 企業のホームへ。replace なので、ブラウザの「戻る」で登録の画面に戻らない。
    // 移り終わるまで submitting は true のまま（その間に押されても送らない）
    router.replace(homePathFor("company"));
  }

  // 登録はできたが、アイコンだけ保存できなかったとき（PR229）
  if (iconFailed) {
    return (
      <main className="mx-auto mt-16 max-w-2xl space-y-6 px-4 pb-16">
        <PageTitle>新規登録（企業用）</PageTitle>
        <p className="text-sm">登録が完了しました。</p>
        <p className="text-sm text-destructive">アイコンを保存できませんでした。あとで会社情報から登録してください</p>
        <Link href={homePathFor("company")} replace className={buttonVariants()}>
          募集一覧へ進む
        </Link>
      </main>
    );
  }

  return (
    <main className="mx-auto mt-16 max-w-2xl space-y-6 px-4 pb-16">
      <div className="space-y-2">
        <PageTitle>新規登録（企業用）</PageTitle>
        <RequiredNote />
      </div>

      {message && <p className="text-sm text-destructive">{message}</p>}

      {step === 1 ? (
        // noValidate：ブラウザの入力チェックを止め、その場での確認と Rails の確認の文言にそろえる
        <form ref={formRef} onSubmit={handleNext} noValidate>
          <FieldGroup>
            <h2 className="font-bold">アカウント</h2>
            <SignupAccountFields
              values={account}
              onChange={(key, value) => setAccount((current) => ({ ...current, [key]: value }))}
              errors={fieldErrors}
              nameLabel={NAME_LABEL}
              nameAutoComplete="organization"
            />
            <div>
              <Button type="submit">{submitting ? "確認中…" : "次へ"}</Button>
            </div>
          </FieldGroup>
        </form>
      ) : optionsFailed ? (
        <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>
      ) : !options ? (
        <p className="text-sm text-muted-foreground">読み込み中…</p>
      ) : (
        <form ref={formRef} onSubmit={handleRegister} noValidate>
          <FieldGroup>
            <div className="space-y-1">
              <h2 className="font-bold">会社情報</h2>
              {/* 最後のステップなので「あとで入力する」は出さない（PR228） */}
              <FieldDescription>空欄のままでも登録できます。あとで会社情報から入力できます</FieldDescription>
            </div>
            <CompanyInfoFields
              values={info}
              onChange={(change) => setInfo((current) => ({ ...current, ...change }))}
              errors={fieldErrors}
              options={options}
            />
            <IconField picker={iconPicker} currentUrl={null} name={account.name} errors={fieldErrors.icon} />
            <div className="flex gap-2">
              {/* 入力は消さずにステップ1へ戻る */}
              <Button type="button" variant="outline" onClick={() => goToStep(1)}>
                戻る
              </Button>
              <Button type="submit">{submitting ? "登録中…" : "登録する"}</Button>
            </div>
          </FieldGroup>
        </form>
      )}

      <p className="text-sm">
        <Link href={loginPathFor("company")} className="underline">
          すでにアカウントをお持ちの方はこちら
        </Link>
      </p>
    </main>
  );
}
