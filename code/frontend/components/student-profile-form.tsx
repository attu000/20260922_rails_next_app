"use client";

// マイページ（S1 学生プロフィール編集）の入力フォーム。詳しくは design/designs/ページ設計.md の 6-6 S1、API設計.md の 16-3 ⑦⑮⑯⑰。
// 開いたら ⑦ 選択肢と ⑮ 自分のプロフィールを SWR で取り、保存で ⑯ を送る。アイコンを選んでいたら、⑯ の成功後に ⑰ を続けて送る。
// 入力欄は6つのまとまり（基本・学校・自己PR・プログラミング歴・就活状況・稼働条件）に分け、見出しの行を押すと開く形（アコーディオン）にしている。
// 必須は氏名と活動状況だけ（その他決め事.md の 5-9）。
// 性格5軸は順9（【強み】）、外部リンク・資格・興味のある業界・就活希望エリアは【仕上げ】で足す

import { useEffect, useRef, useState, type FormEvent } from "react";
import {
  FormSection,
  LONG_TEXT_MAX_LENGTH,
  LongTextField,
  MonthField,
  RequiredNote,
  SHORT_TEXT_MAX_LENGTH,
  SelectField,
  TextField,
  toFieldErrorItems,
  type FieldErrors,
  type InputProps,
} from "@/components/form-fields";
import { IconField, uploadIcon, useIconPicker, validateIconFile } from "@/components/icon-field";
import { JobCategoryPicker } from "@/components/job-category-picker";
import { MasterCheckboxGroup } from "@/components/master-checkbox-group";
import { useRedirectIfUnauthorized, useRefreshMe } from "@/components/member-only";
import { PageTitle } from "@/components/page-title";
import {
  SkillRowsField,
  toSkillRequest,
  toSkillRows,
  validateSkillRows,
  type SkillRow,
} from "@/components/skill-rows-field";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Field, FieldError, FieldLabel, FieldLegend, FieldSet } from "@/components/ui/field";
import { ApiError, apiFetch, useApi } from "@/lib/api";
import {
  currentYearInTokyo,
  isHalfSelectedMonth,
  joinMonthDate,
  splitMonthDate,
  toNumberOrNull,
  toStringOrNull,
  toText,
  yearChoices,
} from "@/lib/form-values";
import { useOptions } from "@/lib/options";
import type { StudentProfile } from "@/lib/student-profile";

// 大学の選択欄で「その他（一覧にない大学）」を表す値
const OTHER_UNIVERSITY = "other";

// フォームが持つ値。入力欄にそのまま入れるため、空欄は "" で持つ（選択欄の数値も文字で持つ）。
// 大学は「一覧の大学の番号」か「その他」を1つの選択欄で持ち、開始時期は年と月の2つの選択欄に分けて持つ
type FormValues = {
  name: string;
  activity_status: string;
  prefecture_id: string;
  // "" 未選択 ／ "3" 大学の番号 ／ "other" その他
  university: string;
  university_other_name: string;
  faculty_id: string;
  department_id: string;
  grade: string;
  self_pr_strength: string;
  self_pr_weakness: string;
  self_pr_future: string;
  graduation_year: string;
  interested_job_middle_category_ids: number[];
  work_days_per_week: string;
  work_hours_per_day: string;
  duration_months: string;
  available_year: string;
  available_month: string;
  can_full_remote: boolean;
  can_partial_remote: boolean;
  can_onsite: boolean;
  commutable_prefecture_ids: number[];
  work_note: string;
  skills: SkillRow[];
};

// 文字の入力欄の名前
type TextKey = {
  [K in keyof FormValues]: FormValues[K] extends string ? K : never;
}[keyof FormValues];

// 氏名の長さの上限。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）
const NAME_MAX_LENGTH = 100;

// 長い文章の項目名。その場での確認の文言を、Rails と同じ「項目名＋理由」の形にするために使う（config/locales/ja.yml と同じ）
const LONG_TEXT_LABELS = {
  self_pr_strength: "自己PR（強み・向いていること）",
  self_pr_weakness: "自己PR（向いていないこと）",
  self_pr_future: "自己PR（この先やりたいこと）",
  work_note: "稼働条件の備考",
} as const satisfies Partial<Record<TextKey, string>>;

// 勤務形態の可否のチェック3つ（その他決め事.md の 5-6。学生は可能なものを複数選ぶ）
const WORK_STYLE_CHECKS = [
  { key: "can_full_remote", label: "フルリモート" },
  { key: "can_partial_remote", label: "一部リモート" },
  { key: "can_onsite", label: "出社" },
] as const;

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
    hint: "卒業年度・興味のある職種",
    fields: ["graduation_year", "interested_job_middle_category_ids"],
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
  // 一覧の大学がなく「その他」の名前があれば、選択欄は「その他」
  const university =
    profile.university_id !== null
      ? String(profile.university_id)
      : profile.university_other_name
        ? OTHER_UNIVERSITY
        : "";
  const { year, month } = splitMonthDate(profile.available_from);
  return {
    name: profile.name,
    activity_status: toText(profile.activity_status),
    prefecture_id: toText(profile.prefecture_id),
    university,
    university_other_name: toText(profile.university_other_name),
    faculty_id: toText(profile.faculty_id),
    department_id: toText(profile.department_id),
    grade: toText(profile.grade),
    self_pr_strength: toText(profile.self_pr_strength),
    self_pr_weakness: toText(profile.self_pr_weakness),
    self_pr_future: toText(profile.self_pr_future),
    graduation_year: toText(profile.graduation_year),
    interested_job_middle_category_ids: profile.interested_job_middle_category_ids,
    work_days_per_week: toText(profile.work_days_per_week),
    work_hours_per_day: toText(profile.work_hours_per_day),
    duration_months: toText(profile.duration_months),
    available_year: year,
    available_month: month,
    can_full_remote: profile.can_full_remote,
    can_partial_remote: profile.can_partial_remote,
    can_onsite: profile.can_onsite,
    commutable_prefecture_ids: profile.commutable_prefecture_ids,
    work_note: toText(profile.work_note),
    skills: toSkillRows(profile.skills),
  };
}

// フォームの値を、⑯ に送る形に直す。フォームの全項目を送る（API設計.md の 16-3 ⑯）。
// 空欄の数値・選択は null。空欄の文章は "" のまま送る（Rails が null にそろえる）
function toRequestBody(values: FormValues) {
  const isOtherUniversity = values.university === OTHER_UNIVERSITY;
  return {
    name: values.name,
    activity_status: toStringOrNull(values.activity_status),
    prefecture_id: toNumberOrNull(values.prefecture_id),
    // 「その他」なら大学の番号は null で名前を送り、一覧の大学なら名前は null（両方同時には入らない。データベース.md の 8-5）
    university_id: isOtherUniversity ? null : toNumberOrNull(values.university),
    university_other_name: isOtherUniversity ? values.university_other_name : null,
    faculty_id: toNumberOrNull(values.faculty_id),
    department_id: toNumberOrNull(values.department_id),
    grade: toStringOrNull(values.grade),
    self_pr_strength: values.self_pr_strength,
    self_pr_weakness: values.self_pr_weakness,
    self_pr_future: values.self_pr_future,
    graduation_year: toNumberOrNull(values.graduation_year),
    interested_job_middle_category_ids: values.interested_job_middle_category_ids,
    work_days_per_week: toNumberOrNull(values.work_days_per_week),
    work_hours_per_day: toNumberOrNull(values.work_hours_per_day),
    duration_months: toNumberOrNull(values.duration_months),
    available_from: joinMonthDate(values.available_year, values.available_month),
    can_full_remote: values.can_full_remote,
    can_partial_remote: values.can_partial_remote,
    can_onsite: values.can_onsite,
    commutable_prefecture_ids: values.commutable_prefecture_ids,
    work_note: values.work_note,
    skills: toSkillRequest(values.skills),
  };
}

// その場で分かる確認だけを行う（17-3-2）。Rails も同じ確認をするので、ここをすり抜けても守られる。
// 文言は Rails と同じにする（開始時期の「年と月の両方」と、「大学名を入力してください」は画面側だけの文言。17-3-6）
function validateOnScreen(values: FormValues, iconFile: File | null): FieldErrors {
  const errors: FieldErrors = {};

  if (values.name.trim() === "") {
    errors.name = ["氏名を入力してください"];
  } else if (values.name.length > NAME_MAX_LENGTH) {
    errors.name = [`氏名は${NAME_MAX_LENGTH}文字以内で入力してください`];
  }
  if (values.activity_status === "") {
    errors.activity_status = ["活動状況を入力してください"];
  }

  if (values.university === OTHER_UNIVERSITY) {
    if (values.university_other_name.trim() === "") {
      errors.university_other_name = ["大学名を入力してください"];
    } else if (values.university_other_name.length > SHORT_TEXT_MAX_LENGTH) {
      errors.university_other_name = [`大学名は${SHORT_TEXT_MAX_LENGTH}文字以内で入力してください`];
    }
  }

  for (const [key, label] of Object.entries(LONG_TEXT_LABELS) as [TextKey, string][]) {
    if (values[key].length > LONG_TEXT_MAX_LENGTH) {
      errors[key] = [`${label}は${LONG_TEXT_MAX_LENGTH}文字以内で入力してください`];
    }
  }

  // 開始時期は、年と月の両方を選ぶか、両方空欄にする
  if (isHalfSelectedMonth(values.available_year, values.available_month)) {
    errors.available_from = ["開始時期は年と月の両方を選んでください"];
  }

  const iconErrors = validateIconFile(iconFile);
  if (iconErrors) {
    errors.icon = iconErrors;
  }

  return { ...errors, ...validateSkillRows(values.skills) };
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

  function updateValue<K extends keyof FormValues>(key: K, value: FormValues[K]) {
    setValues((current) => (current ? { ...current, [key]: value } : current));
    setSaved(false);
  }

  // 学部を変えたら、学科を空に戻す（学科は学部ごとの一覧から選ぶため）
  function updateFaculty(facultyId: string) {
    setValues((current) => (current ? { ...current, faculty_id: facultyId, department_id: "" } : current));
    setSaved(false);
  }

  // プログラミング歴を変えたら、プログラミング歴のエラーを消す。
  // エラーの名前に行の番号が入っているので、行を足したり消したりすると、エラーが別の行の下に出てしまうため。保存を押せば確かめ直される
  function updateSkills(rows: SkillRow[]) {
    updateValue("skills", rows);
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

  // ここから下は、値がそろっている（null ではない）
  const formValues = values;

  // 選んでいる学部の学科（学部を選ぶまでは空）
  const departments =
    options.masters.faculties.find((faculty) => String(faculty.id) === values.faculty_id)?.departments ?? [];
  const commutableCount = values.commutable_prefecture_ids.length;

  // 入力欄の部品に渡す値・変更の関数・エラーを、項目の名前からまとめて作る
  function textProps(name: TextKey): InputProps {
    return {
      id: name,
      value: formValues[name],
      onChange: (value: string) => updateValue(name, value),
      errors: fieldErrors[name],
    };
  }

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

  // マスタの行を、選択欄の選択肢の形に直す
  const toChoices = (rows: { id: number; name: string }[]) =>
    rows.map((row) => ({ value: String(row.id), label: row.name }));

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
            <TextField {...textProps("name")} label="氏名" required />
            <SelectField
              {...textProps("activity_status")}
              label="活動状況"
              required
              emptyLabel="選択してください"
              choices={options.enums.activity_status}
              description="「今は探していない」を選んでも、企業の学生検索には表示されます"
            />
            <SelectField
              {...textProps("prefecture_id")}
              label="在住の都道府県"
              emptyLabel="選択してください"
              choices={toChoices(options.masters.prefectures)}
            />
            <IconField
              picker={iconPicker}
              currentUrl={currentIconUrl}
              name={values.name}
              errors={fieldErrors.icon}
              onFileChange={() => setSaved(false)}
            />
          </FormSection>

          <FormSection {...sectionProps("school")}>
            {/* 大学の選択欄のエラーは、一覧の大学の番号（university_id）のもの */}
            <SelectField
              {...textProps("university")}
              errors={fieldErrors.university_id}
              label="大学"
              emptyLabel="選択してください"
              choices={[
                ...toChoices(options.masters.universities),
                { value: OTHER_UNIVERSITY, label: "その他（一覧にない大学）" },
              ]}
            />
            {/* 「その他」を選んだときだけ、大学名の入力欄を出す（海外の大学など） */}
            {values.university === OTHER_UNIVERSITY && (
              <TextField {...textProps("university_other_name")} label="大学名" />
            )}
            <SelectField
              {...textProps("faculty_id")}
              onChange={updateFaculty}
              label="学部"
              emptyLabel="選択してください"
              choices={toChoices(options.masters.faculties)}
            />
            <SelectField
              {...textProps("department_id")}
              label="学科"
              emptyLabel={values.faculty_id === "" ? "先に学部を選んでください" : "選択してください"}
              choices={toChoices(departments)}
            />
            <SelectField
              {...textProps("grade")}
              label="学年"
              emptyLabel="選択してください"
              choices={options.enums.grade}
            />
          </FormSection>

          <FormSection {...sectionProps("self_pr")}>
            <LongTextField {...textProps("self_pr_strength")} label="自分の強み、向いていること" />
            <LongTextField {...textProps("self_pr_weakness")} label="向いていないこと" />
            <LongTextField {...textProps("self_pr_future")} label="この先やりたいこと、挑戦したいこと" />
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
            {/* 卒業年度の選択肢は今年〜10年後。保存済みの年がその外なら足す（Rails 側は範囲を制限しない。ページ設計.md の 6-6 S1） */}
            <SelectField
              {...textProps("graduation_year")}
              label="卒業年度"
              emptyLabel="選択してください"
              choices={yearChoices(currentYear, currentYear + 10, values.graduation_year).map((year) => ({
                value: year,
                label: `${year}年卒`,
              }))}
            />
            <JobCategoryPicker
              name="interested-job-category"
              legend="興味のある職種"
              majors={options.masters.job_major_categories}
              selectedIds={values.interested_job_middle_category_ids}
              disabledIds={[]}
              disabledNote=""
              onChange={(ids) => updateValue("interested_job_middle_category_ids", ids)}
              errors={fieldErrors.interested_job_middle_category_ids}
            />
          </FormSection>

          {/* 稼働条件はすべて任意。学生は「無理なく出せる量（上限）」を入れる（その他決め事.md の 5-6） */}
          <FormSection {...sectionProps("work_conditions")}>
            <SelectField
              {...textProps("work_days_per_week")}
              label="週の稼働日数"
              emptyLabel="指定なし"
              choices={options.work_conditions.work_days_per_week.map((days) => ({
                value: String(days),
                label: `週${days}日まで`,
              }))}
            />
            <SelectField
              {...textProps("work_hours_per_day")}
              label="1日の稼働時間"
              emptyLabel="指定なし"
              choices={options.work_conditions.work_hours_per_day.map((hours) => ({
                value: String(hours),
                label: `1日${hours}時間まで`,
              }))}
            />
            <SelectField
              {...textProps("duration_months")}
              label="継続期間"
              emptyLabel="指定なし"
              choices={options.work_conditions.duration_months.map((months) => ({
                value: String(months),
                label: `${months}ヶ月以上続けられる`,
              }))}
            />
            {/* 開始時期：年と月の2つの選択欄。年の選択肢は募集と同じ1年前〜2年後。範囲の制限はなし（ページ設計.md の 6-6 S1） */}
            <MonthField
              id="available_year"
              label="開始時期"
              year={values.available_year}
              month={values.available_month}
              onYearChange={(value) => updateValue("available_year", value)}
              onMonthChange={(value) => updateValue("available_month", value)}
              years={yearChoices(currentYear - 1, currentYear + 2, values.available_year)}
              errors={fieldErrors.available_from}
              description="その月から働けます、という意味です"
            />

            {/* 勤務形態：可能なものをすべて選ぶ。初期状態は3つとも「可能」 */}
            <FieldSet>
              <FieldLegend variant="label">勤務形態（可能なものすべて）</FieldLegend>
              <div className="flex flex-wrap gap-4">
                {WORK_STYLE_CHECKS.map((check) => (
                  <Field key={check.key} orientation="horizontal" className="w-auto">
                    <Checkbox
                      id={check.key}
                      checked={values[check.key]}
                      onCheckedChange={(checked) => updateValue(check.key, checked)}
                    />
                    <FieldLabel htmlFor={check.key} className="font-normal">
                      {check.label}
                    </FieldLabel>
                  </Field>
                ))}
              </div>
            </FieldSet>

            {/* 出社できる都道府県：47個あって長いので、開閉する行の中に入れ、選んでいる件数を行に出す。初期値はなし */}
            <FieldSet>
              <FieldLegend variant="label">出社できる都道府県</FieldLegend>
              <Accordion multiple className="gap-2">
                <AccordionItem value="commutable_prefectures" className="rounded-lg border">
                  <AccordionTrigger className="items-center px-3 py-2 hover:no-underline">
                    <span>都道府県を選ぶ</span>
                    {commutableCount > 0 && (
                      <span className="mr-2 ml-auto text-xs font-normal text-muted-foreground">
                        {commutableCount}件選択中
                      </span>
                    )}
                  </AccordionTrigger>
                  <AccordionContent keepMounted className="px-3 pb-3">
                    <MasterCheckboxGroup
                      name="commutable-prefecture"
                      legend="出社できる都道府県"
                      hideLegend
                      rows={options.masters.prefectures}
                      selectedIds={values.commutable_prefecture_ids}
                      onChange={(ids) => updateValue("commutable_prefecture_ids", ids)}
                    />
                  </AccordionContent>
                </AccordionItem>
              </Accordion>
              {/* エラーは開閉する行の外に出す（閉じたままでも見えるように） */}
              <FieldError errors={toFieldErrorItems(fieldErrors.commutable_prefecture_ids)} />
            </FieldSet>

            <LongTextField
              {...textProps("work_note")}
              label="稼働条件の備考"
              placeholder="例：テスト期間は稼働を減らしたい"
            />
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
