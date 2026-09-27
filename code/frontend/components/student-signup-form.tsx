"use client";

// 学生の新規登録（S9）の中身。詳しくは design/designs/ページ設計.md の 6-6 S9、API設計.md の 16-3 ④⑥⑰。
// アカウント → 基本情報 → 興味 → スキル → 稼働条件 → 働き方の好み → 自己PR の7ステップ。
// 入力は画面の中だけで持ち、最後の「登録する」で ⑥ にまとめて送る（途中でやめた人のデータは残らない。途中で読み込み直すと、入力は消える）。
// 登録できたら Rails が自動でログインした状態にするので、アイコンを選んでいれば ⑰ に続けて送り、学生のホーム（募集一覧）へ移る。
// 必須はステップ1のすべてと、ステップ2の活動状況だけ（権限_バリデーション.md の 17-3-5）。
// ボタンは「戻る」「次へ」（最後だけ「登録する」）。「次へ」は、そのステップの必須と形式を確かめてから進む。
// 飛ばしてよいことは、見出しの下の一言で伝える（PR230）。
// 欄は、マイページと共通の部品（components/student-profile-fields.tsx）。守りは Rails にある。画面側の確認は、送る手間を省くためだけ。
// 利用規約・プライバシーポリシーへの同意と、進み具合の表示（「3／6」）は【仕上げ】で足す

import { useEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import type { FieldErrors } from "@/components/form-fields";
import { IconField, uploadIcon, useIconPicker, validateIconFile } from "@/components/icon-field";
import {
  ACCOUNT_KEYS,
  checkEmail,
  EMPTY_ACCOUNT,
  SignupAccountFields,
  validateAccountOnScreen,
  type AccountValues,
} from "@/components/signup-account-fields";
import { SignupIconFailed, SignupLayout } from "@/components/signup-layout";
import { SkillRowsField, type SkillRow } from "@/components/skill-rows-field";
import {
  ActivityStatusField,
  EMPTY_STUDENT_PROFILE,
  GraduationYearField,
  InterestedIndustriesField,
  InterestedJobCategoriesField,
  PERSONALITY_KEYS,
  ResidencePrefectureField,
  StudentSchoolFields,
  StudentSelfPrFields,
  StudentWorkConditionFields,
  toStudentProfileRequest,
  validateStudentProfile,
  WorkStylePreferenceField,
  type StudentProfileValues,
} from "@/components/student-profile-fields";
import { Button } from "@/components/ui/button";
import { FieldDescription, FieldGroup } from "@/components/ui/field";
import { ApiError, apiFetch } from "@/lib/api";
import { homePathFor, type Me } from "@/lib/auth";
import { currentYearInTokyo } from "@/lib/form-values";
import { useOptions, type Options } from "@/lib/options";

// 名前の項目名（Rails の student_profile.name と同じ）
const NAME_LABEL = "氏名";

// 入力に誤りがあるときに、画面の上に出す一言（Rails の 422 と同じ）
const INVALID_MESSAGE = "入力内容を確認してください";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// 途中のステップの見出しの下に添える一言（PR230）
const OPTIONAL_NOTE = "すべて任意です。空欄のまま次へ進めます。あとでマイページから入力できます";
// おすすめに効く項目のステップに添える一言（ページ設計.md の 6-6 S9。職種と技術は影響が大きい）
const RECOMMEND_NOTE = "入力するとおすすめの精度が上がります";

// ステップ（並びはこの順。1から数える）。
// fields は、そのステップに入っている項目の名前（Rails の errors のキーと同じ）。
// 「次へ」でそのステップの誤りだけを取り出すのと、Rails の 422 のときにどのステップへ戻すかを決めるのに使う
const STEPS: { title: string; notes: string[]; fields: string[] }[] = [
  { title: "アカウント", notes: [], fields: ACCOUNT_KEYS },
  {
    title: "基本情報",
    notes: ["活動状況だけ必須です。ほかは空欄のまま次へ進めます。あとでマイページから入力できます"],
    fields: [
      "activity_status",
      "university_id",
      "university_other_name",
      "faculty_id",
      "department_id",
      "grade",
      "graduation_year",
      "prefecture_id",
    ],
  },
  {
    title: "興味",
    notes: [OPTIONAL_NOTE, RECOMMEND_NOTE],
    fields: ["interested_industry_ids", "interested_job_middle_category_ids"],
  },
  // プログラミング歴の行の誤り（skills[0].years など）も、このステップ（stepOfField で拾う）
  { title: "スキル", notes: [OPTIONAL_NOTE, RECOMMEND_NOTE], fields: ["skills"] },
  {
    title: "稼働条件",
    notes: [OPTIONAL_NOTE],
    fields: [
      "work_days_per_week",
      "work_hours_per_day",
      "duration_months",
      "available_from",
      "can_full_remote",
      "can_partial_remote",
      "can_onsite",
      "commutable_prefecture_ids",
      "work_note",
    ],
  },
  // 見出しの下の一言は付けない（スライダーを見ればわかるため。画面の文字を増やさない。PR243 は取り下げ）
  { title: "働き方の好み", notes: [], fields: [...PERSONALITY_KEYS] },
  {
    title: "自己PR",
    notes: ["空欄のままでも登録できます。あとでマイページから入力できます"],
    fields: ["self_pr_strength", "self_pr_weakness", "self_pr_future", "icon"],
  },
];

// 最後のステップの番号（ここで「登録する」）
const LAST_STEP = STEPS.length;

// プログラミング歴のエラー（欄全体の skills と、行ごとの skills[0].years など）か
function isSkillsErrorKey(key: string): boolean {
  return key === "skills" || key.startsWith("skills[");
}

// その項目が入っているステップの番号。どのステップにも当たらない項目は、最後のステップにする
function stepOfField(key: string): number {
  const index = STEPS.findIndex(
    (step) => step.fields.includes(key) || (step.fields.includes("skills") && isSkillsErrorKey(key)),
  );
  return index === -1 ? LAST_STEP : index + 1;
}

// 誤りのうち、そのステップの項目のものだけを取り出す
function errorsOfStep(errors: FieldErrors, step: number): FieldErrors {
  return Object.fromEntries(Object.entries(errors).filter(([key]) => stepOfField(key) === step));
}

export function StudentSignupForm() {
  const router = useRouter();
  const { options, failed: optionsFailed } = useOptions();

  const [step, setStep] = useState(1);
  // ステップ1の値（氏名を含む）と、ステップ2〜7の値。ステップを行き来しても消えない
  const [account, setAccount] = useState<AccountValues>(EMPTY_ACCOUNT);
  const [profile, setProfile] = useState<StudentProfileValues>(EMPTY_STUDENT_PROFILE);
  // 選んだ（まだ送っていない）アイコン（components/icon-field.tsx）
  const iconPicker = useIconPicker();
  // 今年は、画面を開いたときに1回だけ数える
  const [currentYear] = useState(currentYearInTokyo);

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

  // 最初のエラーの項目まで画面を動かす（企業の新規登録と同じ）
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

  function goToStep(next: number) {
    setStep(next);
    setMessage(null);
    // 次のステップは、画面の上から見せる
    window.scrollTo({ top: 0 });
  }

  // 変えた項目と値の組を、今の値に重ねる（共通の部品から呼ばれる）
  function changeProfile(change: Partial<StudentProfileValues>) {
    setProfile((current) => ({ ...current, ...change }));
  }

  // プログラミング歴を変えたら、プログラミング歴のエラーを消す（マイページと同じ理由。行の番号がずれるため）
  function updateSkills(rows: SkillRow[]) {
    changeProfile({ skills: rows });
    setFieldErrors((current) =>
      Object.fromEntries(Object.entries(current).filter(([key]) => !isSkillsErrorKey(key))),
    );
  }

  // 「次へ」「登録する」。ステップによって行うことが違う
  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で進める
    event.preventDefault();
    if (submitting) return;

    if (step === 1) {
      await goNextFromAccount();
    } else if (step < LAST_STEP) {
      // ステップ2〜6：全体を確かめ、そのステップの項目の誤りだけを見る。なければ次へ
      const stepErrors = errorsOfStep(validateStudentProfile(profile), step);
      if (Object.keys(stepErrors).length > 0) {
        showErrors(stepErrors);
        return;
      }
      setFieldErrors({});
      goToStep(step + 1);
    } else {
      await register();
    }
  }

  // ステップ1の「次へ」：その場の確認 → ④ メールアドレスの確認 → ステップ2へ（企業の新規登録と同じ）
  async function goNextFromAccount() {
    const screenErrors = validateAccountOnScreen(account, NAME_LABEL);
    if (Object.keys(screenErrors).length > 0) {
      showErrors(screenErrors);
      return;
    }
    setSubmitting(true);
    try {
      // 全部入力した後にやり直しにならないよう、ここでメールアドレスが使えるかを確かめる（ページ設計.md の S9）
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

  // 最後のステップの「登録する」：その場の確認 → ⑥ 登録（自動でログイン）→ ⑰ アイコン → 学生のホームへ
  async function register() {
    const screenErrors = errorsOfStep(validateStudentProfile(profile), LAST_STEP);
    const iconErrors = validateIconFile(iconPicker.file);
    if (iconErrors) screenErrors.icon = iconErrors;
    if (Object.keys(screenErrors).length > 0) {
      showErrors(screenErrors);
      return;
    }
    setSubmitting(true);
    setMessage(null);

    try {
      // ① 全ステップの値をまとめて送る（⑥）。返事は形A（ログインした人）
      await apiFetch<Me>("/api/student_registrations", {
        method: "POST",
        body: { ...account, ...toStudentProfileRequest(profile) },
      });
    } catch (error) {
      // 入力の誤り（422）なら、誤りのある項目を含む最初のステップに戻して出す（16-3 ⑥）
      if (error instanceof ApiError && error.status === 422 && error.errors) {
        const errors = error.errors;
        const errorSteps = Object.keys(errors).map(stepOfField);
        if (errorSteps.length > 0) goToStep(Math.min(...errorSteps));
        showErrors(errors);
      } else {
        setMessage(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
      }
      setSubmitting(false);
      return;
    }

    // ② 登録できた（ログインした状態）。アイコンを選んでいたら、続けて送る（⑰。登録の成功後に送る決まり）
    if (iconPicker.file) {
      try {
        await uploadIcon("/api/student/profile/icon", iconPicker.file);
      } catch {
        // 登録は取り消さない。一言と「募集一覧へ進む」を出し、利用者が押して進む（PR229）
        setIconFailed(true);
        setSubmitting(false);
        return;
      }
    }

    // ③ 学生のホームへ。replace なので、ブラウザの「戻る」で登録の画面に戻らない。
    // 移り終わるまで submitting は true のまま（その間に押されても送らない）
    router.replace(homePathFor("student"));
  }

  // ステップ2〜7の欄。選択肢（⑦）がそろってから出す
  function profileStepFields(loadedOptions: Options): ReactNode {
    const fieldsProps = { values: profile, onChange: changeProfile, errors: fieldErrors, options: loadedOptions };
    switch (step) {
      case 2:
        return (
          <>
            <ActivityStatusField {...fieldsProps} />
            <StudentSchoolFields {...fieldsProps} />
            <GraduationYearField {...fieldsProps} currentYear={currentYear} />
            <ResidencePrefectureField {...fieldsProps} />
          </>
        );
      case 3:
        // 業界 → 職種の順（マイページ・募集詳細編集と同じ。PR262）
        return (
          <>
            <InterestedIndustriesField {...fieldsProps} />
            <InterestedJobCategoriesField {...fieldsProps} />
          </>
        );
      case 4:
        return (
          <SkillRowsField
            rows={profile.skills}
            technologies={loadedOptions.masters.technologies}
            categories={loadedOptions.enums.technology_category}
            levels={loadedOptions.enums.skill_level}
            errors={fieldErrors}
            onChange={updateSkills}
          />
        );
      case 5:
        return <StudentWorkConditionFields {...fieldsProps} currentYear={currentYear} />;
      case 6:
        return <WorkStylePreferenceField {...fieldsProps} />;
      default:
        return (
          <>
            <StudentSelfPrFields {...fieldsProps} />
            <IconField picker={iconPicker} currentUrl={null} name={account.name} errors={fieldErrors.icon} />
          </>
        );
    }
  }

  // 登録はできたが、アイコンだけ保存できなかったとき（PR229）
  if (iconFailed) {
    return <SignupIconFailed role="student" />;
  }

  // 今のステップの欄
  let fields: ReactNode;
  if (step === 1) {
    fields = (
      <SignupAccountFields
        values={account}
        onChange={(key, value) => setAccount((current) => ({ ...current, [key]: value }))}
        errors={fieldErrors}
        nameLabel={NAME_LABEL}
        nameAutoComplete="name"
      />
    );
  } else if (optionsFailed) {
    fields = <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  } else if (!options) {
    fields = <p className="text-sm text-muted-foreground">読み込み中…</p>;
  } else {
    fields = profileStepFields(options);
  }

  const currentStep = STEPS[step - 1];
  // 押すボタンの文字
  let submitLabel = "次へ";
  if (step === 1 && submitting) submitLabel = "確認中…";
  if (step === LAST_STEP) submitLabel = submitting ? "登録中…" : "登録する";

  return (
    <SignupLayout role="student">
      {message && <p className="text-sm text-destructive">{message}</p>}

      {/* noValidate：ブラウザの入力チェックを止め、その場での確認と Rails の確認の文言にそろえる */}
      <form ref={formRef} onSubmit={handleSubmit} noValidate>
        <FieldGroup>
          <div className="space-y-1">
            <h2 className="font-bold">{currentStep.title}</h2>
            {currentStep.notes.map((note) => (
              <FieldDescription key={note}>{note}</FieldDescription>
            ))}
          </div>
          {fields}
          <div className="flex gap-2">
            {/* 入力は消さずに前のステップへ戻る */}
            {step > 1 && (
              <Button type="button" variant="outline" onClick={() => goToStep(step - 1)}>
                戻る
              </Button>
            )}
            <Button type="submit">{submitLabel}</Button>
          </div>
        </FieldGroup>
      </form>
    </SignupLayout>
  );
}
