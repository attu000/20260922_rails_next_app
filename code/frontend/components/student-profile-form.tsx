"use client";

// マイページ（S1 学生プロフィール編集）の入力フォーム。詳しくは design/designs/ページ設計.md の 6-6 S1、API設計.md の 16-3 ⑦⑮⑯⑰。
// 開いたら ⑦ 選択肢と ⑮ 自分のプロフィールを SWR で取り、保存で ⑯ を送る。アイコンを選んでいたら、⑯ の成功後に ⑰ を続けて送る。
// 入力欄は7つのまとまり（基本・学校・自己PR・プログラミング歴・就活状況・働き方の好み・稼働条件）に分け、見出しの行を押すと開く形（アコーディオン）にしている。
// 氏名とアイコン以外の欄と、値の変換・その場の確認は、新規登録と共通の部品（components/student-profile-fields.tsx）。
// 必須は氏名と活動状況だけ（その他決め事.md の 5-9）。
// 外部リンク・資格・就活希望エリアは【仕上げ】で足す（興味のある業界は順10 で前倒しした。PR254）

import { useEffect, useRef, useState, type FormEvent } from "react";
import { FormSection, RequiredNote, TextField, type FieldErrors } from "@/components/form-fields";
import { IconField, uploadIcon, useIconPicker, validateIconFile } from "@/components/icon-field";
import { useRedirectIfUnauthorized, useRefreshMe } from "@/components/member-only";
import { PageTitle } from "@/components/page-title";
import { SkillRowsField, type SkillRow } from "@/components/skill-rows-field";
import {
  ActivityStatusField,
  GraduationYearField,
  InterestedIndustriesField,
  InterestedJobCategoriesField,
  PERSONALITY_KEYS,
  ResidencePrefectureField,
  StudentSchoolFields,
  StudentSelfPrFields,
  StudentWorkConditionFields,
  toStudentProfileRequest,
  toStudentProfileValues,
  validateStudentProfile,
  WorkStylePreferenceField,
  type StudentProfileValues,
} from "@/components/student-profile-fields";
import { Accordion } from "@/components/ui/accordion";
import { Button } from "@/components/ui/button";
import { ApiError, apiFetch, useApi } from "@/lib/api";
import { currentYearInTokyo } from "@/lib/form-values";
import { useOptions } from "@/lib/options";
import type { StudentProfile } from "@/lib/student-profile";

// フォームが持つ値。氏名と、共通の部品の値（空欄は "" で持つ）
type FormValues = StudentProfileValues & {
  name: string;
};

// 氏名の長さの上限。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）
const NAME_MAX_LENGTH = 100;

// フォームのまとまり。見出しの行を押すと中身が開く（アコーディオン）。並びはこの順。
// fields は、そのまとまりに入っている項目の名前（エラーのときに、どのまとまりを開くかを決めるのに使う。Rails の errors のキーと同じ）。
// プログラミング歴の行のエラー（skills[0].years など）は、下の sectionHasError で拾う
const SECTIONS = [
  {
    value: "basic",
    title: "基本",
    hint: "氏名・活動状況・在住の都道府県・アイコン",
    fields: ["name", "activity_status", "prefecture_id", "icon"],
  },
  {
    value: "school",
    title: "学校",
    hint: "大学・学部・学科・学年",
    fields: ["university_id", "university_other_name", "faculty_id", "department_id", "grade"],
  },
  {
    value: "self_pr",
    title: "自己PR",
    hint: "3つの問い",
    fields: ["self_pr_strength", "self_pr_weakness", "self_pr_future"],
  },
  { value: "skills", title: "プログラミング歴", hint: "言語・フレームワークと年数・レベル", fields: ["skills"] },
  {
    value: "job_hunting",
    title: "就活状況",
    hint: "卒業年度・興味のある業界・職種",
    fields: ["graduation_year", "interested_industry_ids", "interested_job_middle_category_ids"],
  },
  {
    value: "work_style_preference",
    title: "働き方の好み",
    hint: "進め方・新しさなど5つの軸",
    fields: PERSONALITY_KEYS,
  },
  {
    value: "work_conditions",
    title: "稼働条件",
    hint: "無理なく続けられる範囲で。すべて任意",
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
] as const;

type SectionValue = (typeof SECTIONS)[number]["value"];

// 最初に開いておくまとまり
const INITIAL_OPEN_SECTIONS: SectionValue[] = ["basic"];

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// プログラミング歴のエラー（欄全体の skills と、行ごとの skills[0].years など）か
function isSkillsErrorKey(key: string): boolean {
  return key === "skills" || key.startsWith("skills[");
}

// そのまとまりの項目に、エラーがあるか
function sectionHasError(section: (typeof SECTIONS)[number], errors: FieldErrors): boolean {
  if (section.value === "skills") {
    return Object.keys(errors).some(isSkillsErrorKey);
  }
  return section.fields.some((field) => errors[field] !== undefined);
}

// ⑮ の返事を、フォームの値に直す
function toFormValues(profile: StudentProfile): FormValues {
  return { name: profile.name, ...toStudentProfileValues(profile) };
}

// フォームの値を、⑯ に送る形に直す。フォームの全項目を送る（API設計.md の 16-3 ⑯）
function toRequestBody(values: FormValues) {
  return { name: values.name, ...toStudentProfileRequest(values) };
}

// その場で分かる確認だけを行う（17-3-2）。氏名とアイコンはここで、残りは共通の部品の確認で行う。
// Rails も同じ確認をするので、ここをすり抜けても守られる。文言は Rails と同じにする
function validateOnScreen(values: FormValues, iconFile: File | null): FieldErrors {
  const errors: FieldErrors = validateStudentProfile(values);

  if (values.name.trim() === "") {
    errors.name = ["氏名を入力してください"];
  } else if (values.name.length > NAME_MAX_LENGTH) {
    errors.name = [`氏名は${NAME_MAX_LENGTH}文字以内で入力してください`];
  }

  const iconErrors = validateIconFile(iconFile);
  if (iconErrors) {
    errors.icon = iconErrors;
  }

  return errors;
}

export function StudentProfileForm() {
  const { options, failed: optionsFailed } = useOptions();
  const refreshMe = useRefreshMe();
  const redirectIfUnauthorized = useRedirectIfUnauthorized();

  const [values, setValues] = useState<FormValues | null>(null);
  // 保存済みのアイコンの URL と、選んだ（まだ送っていない）ファイル・プレビュー（components/icon-field.tsx）
  const [currentIconUrl, setCurrentIconUrl] = useState<string | null>(null);
  const iconPicker = useIconPicker();
  // 今年は、画面を開いたときに1回だけ数える
  const [currentYear] = useState(currentYearInTokyo);

  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  // 画面の上に出す一言
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  // 増えたら、最初のエラーの項目まで画面を動かす（17-3-2）
  const [scrollToErrorRequest, setScrollToErrorRequest] = useState(0);
  // 開いているまとまり
  const [openSections, setOpenSections] = useState<SectionValue[]>(INITIAL_OPEN_SECTIONS);

  const formRef = useRef<HTMLFormElement>(null);

  // 開いたら ⑮ 自分のプロフィールを取る。401 は共通の枠がログイン画面へ移す
  const {
    data: profile,
    error: profileError,
    isValidating: profileValidating,
    mutate: mutateProfile,
  } = useApi<StudentProfile>("/api/student/profile");

  // 入力欄の最初の値は、最新を取り終えてから1回だけ入れる（企業プロフィール編集と同じ）。
  // SWR が覚えている古い内容を入れてしまうと、そのあと最新が届いても入力欄は古いままになるため
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

  // 変えた項目と値の組を、今の値に重ねる（共通の部品から呼ばれる）
  function changeValues(change: Partial<FormValues>) {
    setValues((current) => (current ? { ...current, ...change } : current));
    setSaved(false);
  }

  // プログラミング歴を変えたら、プログラミング歴のエラーを消す。
  // エラーの名前に行の番号が入っているので、行を足したり消したりすると、エラーが別の行の下に出てしまうため。保存を押せば確かめ直される
  function updateSkills(rows: SkillRow[]) {
    changeValues({ skills: rows });
    setFieldErrors((current) =>
      Object.fromEntries(Object.entries(current).filter(([key]) => !isSkillsErrorKey(key))),
    );
  }

  // エラーを項目に出す。エラーのある項目を含むまとまりは自動で開き（開いているものは閉じない）、最初のエラーまで画面を動かす
  function showErrors(errors: FieldErrors) {
    setFieldErrors(errors);
    const sectionsWithErrors = SECTIONS.filter((section) => sectionHasError(section, errors)).map(
      (section) => section.value,
    );
    setOpenSections((current) => [...new Set([...current, ...sectionsWithErrors])]);
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
      // ① 本体を保存する（⑯）
      const savedProfile = await apiFetch<StudentProfile>("/api/student/profile", {
        method: "PATCH",
        body: toRequestBody(values),
      });
      setValues(toFormValues(savedProfile));
      // SWR が覚えている中身も、保存後の内容に差し替える（取り直しはしない）
      await mutateProfile(savedProfile, { revalidate: false });

      // ② アイコンを選んでいたら、続けて送る（⑰。⑯ の成功後に送る決まり）
      let iconFailed = false;
      if (iconPicker.file) {
        try {
          const iconUrl = await uploadIcon("/api/student/profile/icon", iconPicker.file);
          setCurrentIconUrl(iconUrl);
          await mutateProfile({ ...savedProfile, icon_url: iconUrl }, { revalidate: false });
          iconPicker.clear();
        } catch (error) {
          if (redirectIfUnauthorized(error)) return;
          // 本体の保存は取り消さない
          iconFailed = true;
          setMessage("プロフィールは保存しましたが、アイコンは保存できませんでした");
          if (error instanceof ApiError && error.errors) showErrors(error.errors);
        }
      }

      // ヘッダーの氏名とアイコンを新しくする
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

  // ⑮ が取れなかった。401 のときは共通の枠がログイン画面へ移すので、読み込み中のままにする
  if (!values && profileError && profileError.status !== 401) {
    return <p className="text-sm text-destructive">{profileError.message}</p>;
  }

  if (!options || !values) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  // 共通の部品に渡すもの（値・変えたときの処理・エラー・選択肢）
  const fieldsProps = { values, onChange: changeValues, errors: fieldErrors, options };

  // まとまりの見出しの行に渡す値（題名・一言・エラーがあるか）を、まとまりの名前から作る
  function sectionProps(value: SectionValue) {
    const section = SECTIONS.find((candidate) => candidate.value === value) ?? SECTIONS[0];
    return {
      value,
      title: section.title,
      hint: section.hint,
      hasError: sectionHasError(section, fieldErrors),
    };
  }

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <PageTitle>マイページ</PageTitle>
        <RequiredNote />
      </div>

      {message && <p className="text-sm text-destructive">{message}</p>}

      {/* noValidate：ブラウザの入力チェックを止め、その場での確認と Rails の確認の文言にそろえる */}
      <form ref={formRef} onSubmit={handleSubmit} noValidate className="max-w-3xl space-y-6">
        {/* まとまりを並べる。multiple：いくつでも同時に開いておける */}
        <Accordion
          multiple
          value={openSections}
          onValueChange={(value) => setOpenSections(value as SectionValue[])}
          className="gap-3"
        >
          <FormSection {...sectionProps("basic")}>
            <TextField
              id="name"
              value={values.name}
              onChange={(name) => changeValues({ name })}
              errors={fieldErrors.name}
              label="氏名"
              required
            />
            <ActivityStatusField {...fieldsProps} />
            <ResidencePrefectureField {...fieldsProps} />
            <IconField
              picker={iconPicker}
              currentUrl={currentIconUrl}
              name={values.name}
              errors={fieldErrors.icon}
              onFileChange={() => setSaved(false)}
            />
          </FormSection>

          <FormSection {...sectionProps("school")}>
            <StudentSchoolFields {...fieldsProps} />
          </FormSection>

          <FormSection {...sectionProps("self_pr")}>
            <StudentSelfPrFields {...fieldsProps} />
          </FormSection>

          <FormSection {...sectionProps("skills")}>
            <SkillRowsField
              rows={values.skills}
              technologies={options.masters.technologies}
              categories={options.enums.technology_category}
              levels={options.enums.skill_level}
              errors={fieldErrors}
              onChange={updateSkills}
            />
          </FormSection>

          <FormSection {...sectionProps("job_hunting")}>
            <GraduationYearField {...fieldsProps} currentYear={currentYear} />
            {/* 業界 → 職種の順（募集詳細編集と同じ。PR262） */}
            <InterestedIndustriesField {...fieldsProps} />
            <InterestedJobCategoriesField {...fieldsProps} />
          </FormSection>

          <FormSection {...sectionProps("work_style_preference")}>
            <WorkStylePreferenceField {...fieldsProps} />
          </FormSection>

          <FormSection {...sectionProps("work_conditions")}>
            <StudentWorkConditionFields {...fieldsProps} currentYear={currentYear} />
          </FormSection>
        </Accordion>

        <div className="flex items-center gap-4">
          <Button type="submit">{saving ? "保存中…" : "保存"}</Button>
          {saved && <p className="text-sm text-muted-foreground">保存しました</p>}
        </div>
      </form>
    </div>
  );
}
