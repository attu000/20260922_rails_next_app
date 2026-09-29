"use client";

// 募集詳細編集（C3）の入力フォーム。新規作成と編集で同じものを使う。
// 詳しくは design/designs/ページ設計.md の 6-5 C3、API設計.md の 16-3 ⑦⑧⑫⑬⑭。
// 開いたら ⑦ 選択肢と ⑧ 自社のプロフィール（会社名と、空欄のときに薄く出す値）を取り、編集なら ⑫ 募集1件も取る。
// 保存は、新規なら ⑬、編集なら ⑭ を送り、成功したら募集一覧へ戻る。
// 入力欄は9つのまとまり（基本・業界と事業形態・職種・工程・募集概要・要件と使用技術・給与・稼働条件・カルチャー）に分け、
// 見出しの行を押すと開く形（アコーディオン）にしている。
// 必須は2段（その他決め事.md の 5-9）：常に必須は状態・タイトル。インターンですること・時給は「掲載に必要」（状態が掲載中のときだけ必須）。
// カルチャーも常に必須だが、最初から真ん中に値があって空にできないので、赤い「＊」は付けない（PR248）。
// 目的・求める人材は【仕上げ】で足す

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { CultureAxesField } from "@/components/culture-axes-field";
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
import { JobCategoryPicker } from "@/components/job-category-picker";
import { JobTrialCheckboxGroup } from "@/components/job-trial-checkbox-group";
import { MasterCheckboxGroup } from "@/components/master-checkbox-group";
import { useRedirectIfUnauthorized } from "@/components/member-only";
import { PageTitle } from "@/components/page-title";
import { TechnologyPicker } from "@/components/technology-picker";
import { WorkProcessPicker } from "@/components/work-process-picker";
import { Accordion } from "@/components/ui/accordion";
import { Button, buttonVariants } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Field, FieldDescription, FieldError, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { ApiError, apiFetch, useApi } from "@/lib/api";
import {
  currentYearInTokyo,
  isHalfSelectedMonth,
  joinMonthDate,
  splitMonthDate,
  toNumberOrNull,
  toText,
  yearChoices,
} from "@/lib/form-values";
import type { JobPosting } from "@/lib/job-postings";
import { useOptions } from "@/lib/options";
import { roleOf, selectedIdsOf, withRole, withSelectedIds, type Role, type RoleIds } from "@/lib/role-ids";

// ⑧ の返事のうち、この画面で使う項目
type CompanyDefaults = {
  name: string;
  about: string | null;
  business_description: string | null;
};

// フォームが持つ値。入力欄にそのまま入れるため、空欄は "" で持つ（選択欄の数値も文字で持つ）。
// 開始時期だけは、年と月の2つの選択欄に分けて持ち、送るときに "2026-10-01" の形にまとめる
type FormValues = {
  status: string;
  title: string;
  about: string;
  business_description: string;
  internship_details: string;
  growth: string;
  min_work_days_per_week: string;
  min_work_hours_per_day: string;
  min_duration_months: string;
  start_year: string;
  start_month_number: string;
  work_style: string;
  work_style_note: string;
  prefecture_id: string;
  work_location_note: string;
  weekend_ok: boolean;
  work_note: string;
  hourly_wage: string;
  requirements: string;
  preferred_requirements: string;
  technology_note: string;
  main_job_middle_category_ids: number[];
  related_job_middle_category_ids: number[];
  main_work_process_ids: number[];
  involved_work_process_ids: number[];
  technology_ids: number[];
  industry_ids: number[];
  business_type_ids: number[];
  // この募集に近いプチ職業体験の講座（順19）
  job_trial_ids: number[];
  // カルチャーの5軸は、スライダーの位置（−2〜2）を数のまま持つ（空欄がないため）
  culture_pace: number;
  culture_novelty: number;
  culture_collaboration: number;
  culture_decision: number;
  culture_atmosphere: number;
};

// カルチャーの5軸の項目名。Rails の列名・エラーのキーと同じ
const CULTURE_KEYS = [
  "culture_pace",
  "culture_novelty",
  "culture_collaboration",
  "culture_decision",
  "culture_atmosphere",
] as const;

type CultureKey = (typeof CULTURE_KEYS)[number];

// 軸の名前（"pace"）から、カルチャーの項目名（"culture_pace"）を引く。知らない軸なら undefined
function cultureKeyOf(axisKey: string): CultureKey | undefined {
  return CULTURE_KEYS.find((key) => key === `culture_${axisKey}`);
}

// 文字の入力欄の名前
type TextKey = {
  [K in keyof FormValues]: FormValues[K] extends string ? K : never;
}[keyof FormValues];

// 時給の上限。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）。
// 文字数の上限は components/form-fields.tsx の SHORT_TEXT_MAX_LENGTH・LONG_TEXT_MAX_LENGTH
const HOURLY_WAGE_MAX = 100000;

// 項目名。その場での確認の文言を、Rails と同じ「項目名＋理由」の形にするために使う（config/locales/ja.yml と同じ）
const SHORT_TEXT_LABELS = {
  title: "募集タイトル",
  work_style_note: "勤務形態の補足",
  work_location_note: "最寄り駅など",
} as const satisfies Partial<Record<TextKey, string>>;

// 職種のメイン／サブの切り替えの選択肢（PR234・PR236）
const JOB_CATEGORY_ROLES: { value: Role; label: string }[] = [
  { value: "main", label: "メイン" },
  { value: "sub", label: "サブ" },
];

const LONG_TEXT_LABELS = {
  about: "どんな会社か",
  business_description: "事業内容",
  internship_details: "インターンですること",
  growth: "成長イメージ",
  work_note: "稼働条件の備考",
  requirements: "必須要件",
  preferred_requirements: "歓迎要件",
  technology_note: "使用技術の補足",
} as const satisfies Partial<Record<TextKey, string>>;

// 新規作成のときの最初の値。状態は非公開（書きかけでも保存できる）
const EMPTY_VALUES: FormValues = {
  status: "unpublished",
  title: "",
  about: "",
  business_description: "",
  internship_details: "",
  growth: "",
  min_work_days_per_week: "",
  min_work_hours_per_day: "",
  min_duration_months: "",
  start_year: "",
  start_month_number: "",
  work_style: "",
  work_style_note: "",
  prefecture_id: "",
  work_location_note: "",
  weekend_ok: false,
  work_note: "",
  hourly_wage: "",
  requirements: "",
  preferred_requirements: "",
  technology_note: "",
  main_job_middle_category_ids: [],
  related_job_middle_category_ids: [],
  main_work_process_ids: [],
  involved_work_process_ids: [],
  technology_ids: [],
  industry_ids: [],
  business_type_ids: [],
  job_trial_ids: [],
  // カルチャーは真ん中から（データベースの既定値と同じ）
  culture_pace: 0,
  culture_novelty: 0,
  culture_collaboration: 0,
  culture_decision: 0,
  culture_atmosphere: 0,
};

// フォームのまとまり。見出しの行を押すと中身が開く（アコーディオン）。並びはこの順。
// fields は、そのまとまりに入っている項目の名前（エラーのときに、どのまとまりを開くかを決めるのに使う。Rails の errors のキーと同じ）
const SECTIONS = [
  { value: "basic", title: "基本", hint: "募集状態・タイトル", fields: ["status", "title"] },
  {
    value: "industries",
    title: "業界・事業形態",
    // 会社情報にも同じ欄があるので、「この募集の」値であることを見出しの横で伝える
    hint: "この募集の事業の分野と形",
    fields: ["industry_ids", "business_type_ids"],
  },
  {
    value: "job_categories",
    title: "職種",
    hint: "メイン・サブ",
    fields: ["main_job_middle_category_ids", "related_job_middle_category_ids"],
  },
  // 職種と別のまとまりにする（職種の一覧は開くと長くなるので、1つのまとまりが長くなりすぎないように。PR247）
  {
    value: "work_processes",
    title: "工程",
    hint: "メイン・関われる",
    fields: ["main_work_process_ids", "involved_work_process_ids"],
  },
  {
    value: "overview",
    title: "募集概要",
    hint: "インターンですること（掲載に必要）など",
    fields: ["about", "business_description", "internship_details", "growth"],
  },
  {
    value: "requirements",
    title: "要件・使用技術",
    hint: "必須要件・歓迎要件・使用技術",
    fields: ["requirements", "preferred_requirements", "technology_ids", "technology_note"],
  },
  { value: "wage", title: "給与", hint: "時給（掲載に必要）", fields: ["hourly_wage"] },
  {
    value: "work_conditions",
    title: "稼働条件",
    hint: "すべて任意",
    fields: [
      "min_work_days_per_week",
      "min_work_hours_per_day",
      "min_duration_months",
      "start_month",
      "work_style",
      "work_style_note",
      "prefecture_id",
      "work_location_note",
      "weekend_ok",
      "work_note",
    ],
  },
  { value: "culture", title: "カルチャー", hint: "進め方・新しさなど5つの軸", fields: CULTURE_KEYS },
  // 任意の後付けの項目なので、今の並びを崩さずに最後に置く（順19。PR399）
  { value: "job_trials", title: "プチ職業体験", hint: "この募集に近い講座", fields: ["job_trial_ids"] },
] as const;

type SectionValue = (typeof SECTIONS)[number]["value"];

// 最初に開いておくまとまり（新規・編集とも「基本」だけ）
const INITIAL_OPEN_SECTIONS: SectionValue[] = ["basic"];

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// ⑫ の返事を、フォームの値に直す
function toFormValues(posting: JobPosting): FormValues {
  // "2026-10-01" → 年 "2026"、月 "10"
  const { year, month } = splitMonthDate(posting.start_month);
  return {
    status: posting.status,
    title: posting.title,
    about: toText(posting.about),
    business_description: toText(posting.business_description),
    internship_details: toText(posting.internship_details),
    growth: toText(posting.growth),
    min_work_days_per_week: toText(posting.min_work_days_per_week),
    min_work_hours_per_day: toText(posting.min_work_hours_per_day),
    min_duration_months: toText(posting.min_duration_months),
    start_year: year,
    start_month_number: month,
    work_style: toText(posting.work_style),
    work_style_note: toText(posting.work_style_note),
    prefecture_id: toText(posting.prefecture_id),
    work_location_note: toText(posting.work_location_note),
    weekend_ok: posting.weekend_ok,
    work_note: toText(posting.work_note),
    hourly_wage: toText(posting.hourly_wage),
    requirements: toText(posting.requirements),
    preferred_requirements: toText(posting.preferred_requirements),
    technology_note: toText(posting.technology_note),
    main_job_middle_category_ids: posting.main_job_middle_category_ids,
    related_job_middle_category_ids: posting.related_job_middle_category_ids,
    main_work_process_ids: posting.main_work_process_ids,
    involved_work_process_ids: posting.involved_work_process_ids,
    technology_ids: posting.technology_ids,
    industry_ids: posting.industry_ids,
    business_type_ids: posting.business_type_ids,
    job_trial_ids: posting.job_trial_ids,
    culture_pace: posting.culture_pace,
    culture_novelty: posting.culture_novelty,
    culture_collaboration: posting.culture_collaboration,
    culture_decision: posting.culture_decision,
    culture_atmosphere: posting.culture_atmosphere,
  };
}

// フォームの値を、⑬⑭ に送る形に直す。空欄の数値・選択は null、開始時期は "2026-10-01" の形にする。
// 空欄の文章は "" のまま送る（Rails が null にそろえる）
function toRequestBody(values: FormValues) {
  const { start_year: startYear, start_month_number: startMonthNumber, ...rest } = values;
  return {
    ...rest,
    min_work_days_per_week: toNumberOrNull(values.min_work_days_per_week),
    min_work_hours_per_day: toNumberOrNull(values.min_work_hours_per_day),
    min_duration_months: toNumberOrNull(values.min_duration_months),
    start_month: joinMonthDate(startYear, startMonthNumber),
    work_style: values.work_style === "" ? null : values.work_style,
    prefecture_id: toNumberOrNull(values.prefecture_id),
    hourly_wage: toNumberOrNull(values.hourly_wage),
  };
}

// その場で分かる確認だけを行う（17-3-2）。Rails も同じ確認をするので、ここをすり抜けても守られる。
// 文言は Rails と同じにする（開始時期の「年と月の両方」だけは画面側だけの文言。17-3-6）
function validateOnScreen(values: FormValues): FieldErrors {
  const errors: FieldErrors = {};

  if (values.title.trim() === "") {
    errors.title = ["募集タイトルを入力してください"];
  }
  for (const [key, label] of Object.entries(SHORT_TEXT_LABELS) as [TextKey, string][]) {
    if (values[key].length > SHORT_TEXT_MAX_LENGTH) {
      errors[key] = [`${label}は${SHORT_TEXT_MAX_LENGTH}文字以内で入力してください`];
    }
  }
  for (const [key, label] of Object.entries(LONG_TEXT_LABELS) as [TextKey, string][]) {
    if (values[key].length > LONG_TEXT_MAX_LENGTH) {
      errors[key] = [`${label}は${LONG_TEXT_MAX_LENGTH}文字以内で入力してください`];
    }
  }

  // 掲載に必要：状態が掲載中のときだけ確かめる
  if (values.status === "published") {
    if (values.internship_details.trim() === "") {
      errors.internship_details = ["インターンですることを入力してください"];
    }
    if (values.hourly_wage.trim() === "") {
      errors.hourly_wage = ["時給を入力してください"];
    }
  }
  // 時給は、入っていれば 1〜100,000 の整数
  if (values.hourly_wage.trim() !== "") {
    const wage = Number(values.hourly_wage);
    if (Number.isNaN(wage)) {
      errors.hourly_wage = ["時給は数値で入力してください"];
    } else if (!Number.isInteger(wage)) {
      errors.hourly_wage = ["時給は整数で入力してください"];
    } else if (wage < 1) {
      errors.hourly_wage = ["時給は1以上の値にしてください"];
    } else if (wage > HOURLY_WAGE_MAX) {
      errors.hourly_wage = [`時給は${HOURLY_WAGE_MAX}以下の値にしてください`];
    }
  }

  // 開始時期は、年と月の両方を選ぶか、両方空欄（随時）にする
  if (isHalfSelectedMonth(values.start_year, values.start_month_number)) {
    errors.start_month = ["開始時期は年と月の両方を選んでください"];
  }

  return errors;
}

type JobPostingFormProps = {
  // 編集する募集の番号（URL の [id] の部分）。新規作成なら null
  jobPostingId: string | null;
};

export function JobPostingForm({ jobPostingId }: JobPostingFormProps) {
  const isNew = jobPostingId === null;
  // 編集する募集の API の URL。URL の [id] の部分は利用者が書き換えられるので、符号化してから入れる
  const postingPath =
    jobPostingId === null ? null : `/api/company/job_postings/${encodeURIComponent(jobPostingId)}`;
  const router = useRouter();
  const redirectIfUnauthorized = useRedirectIfUnauthorized();

  // 401 は共通の枠（member-only.tsx）がログイン画面へ移す
  const { options, failed: optionsFailed } = useOptions();
  const { data: company } = useApi<CompanyDefaults>("/api/company/profile");
  // 新規なら取らない（null を渡す）
  const {
    data: posting,
    error: postingError,
    isValidating: postingValidating,
    mutate: mutatePosting,
  } = useApi<JobPosting>(postingPath);

  const [values, setValues] = useState<FormValues | null>(isNew ? EMPTY_VALUES : null);
  // 今年は、画面を開いたときに1回だけ数える
  const [currentYear] = useState(currentYearInTokyo);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  // 画面の上に出す一言
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  // 増えたら、最初のエラーの項目まで画面を動かす（17-3-2）
  const [scrollToErrorRequest, setScrollToErrorRequest] = useState(0);
  // 開いているまとまり
  const [openSections, setOpenSections] = useState<SectionValue[]>(INITIAL_OPEN_SECTIONS);

  const formRef = useRef<HTMLFormElement>(null);

  // 編集のとき、入力欄の最初の値は、最新を取り終えてから1回だけ入れる（企業プロフィール編集と同じ）。
  // SWR が覚えている古い内容を入れてしまうと、そのあと最新が届いても入力欄は古いままになるため
  if (values === null && posting && !postingValidating) {
    setValues(toFormValues(posting));
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
  }

  // 職種を、主な職種・関連する職種の2つの一覧に分け直して入れる（画面では1つの一覧で見せる。PR234）
  function updateJobCategories(roleIds: RoleIds) {
    setValues((current) =>
      current
        ? { ...current, main_job_middle_category_ids: roleIds.main, related_job_middle_category_ids: roleIds.sub }
        : current,
    );
  }

  // エラーを項目に出す。エラーのある項目を含むまとまりは自動で開き（開いているものは閉じない）、最初のエラーまで画面を動かす。
  // 閉じたまとまりの中にエラーが隠れて、「なぜ保存できないのか分からない」とならないようにするため
  function showErrors(errors: FieldErrors) {
    setFieldErrors(errors);
    const sectionsWithErrors = SECTIONS.filter((section) =>
      section.fields.some((field) => errors[field]),
    ).map((section) => section.value);
    setOpenSections((current) => [...new Set([...current, ...sectionsWithErrors])]);
    setScrollToErrorRequest((count) => count + 1);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で送る
    event.preventDefault();
    // 2回押しても、1回だけ送る。ボタンは押せなくしない（17-3-2）
    if (!values || saving) return;

    setMessage(null);
    const screenErrors = validateOnScreen(values);
    if (Object.keys(screenErrors).length > 0) {
      setMessage("入力内容を確認してください");
      showErrors(screenErrors);
      return;
    }
    setFieldErrors({});
    setSaving(true);

    try {
      const body = toRequestBody(values);
      if (postingPath === null) {
        // ⑬ 新規作成
        await apiFetch<JobPosting>("/api/company/job_postings", { method: "POST", body });
      } else {
        // ⑭ 保存。SWR が覚えている1件も、保存後の内容に差し替える（取り直しはしない）
        const saved = await apiFetch<JobPosting>(postingPath, { method: "PATCH", body });
        await mutatePosting(saved, { revalidate: false });
      }
      // 保存したら募集一覧へ戻る（ページ設計.md の 6-5 C3）。一覧は、開いたときに SWR が取り直す
      router.push("/company/job_postings");
    } catch (error) {
      if (redirectIfUnauthorized(error)) return;
      if (error instanceof ApiError && error.status === 422 && error.errors) {
        showErrors(error.errors);
      }
      setMessage(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
      setSaving(false);
    }
  }

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  // ⑫ が取れなかった（他社の募集・存在しない番号なら「見つかりません」）。401 は共通の枠がログイン画面へ移すので、読み込み中のままにする
  if (!values && postingError && postingError.status !== 401) {
    return <p className="text-sm text-destructive">{postingError.message}</p>;
  }

  if (!options || !values) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  // ここから下は、値がそろっている（null ではない）
  const formValues = values;

  // 職種の、メイン（主な職種）とサブ（関連する職種）の番号の一覧
  const jobCategoryRoleIds: RoleIds = {
    main: values.main_job_middle_category_ids,
    sub: values.related_job_middle_category_ids,
  };
  // 職種のエラー。主な職種・関連する職種のどちらのものも、1つの欄の下にまとめて出す
  const jobCategoryErrors = [
    ...(fieldErrors.main_job_middle_category_ids ?? []),
    ...(fieldErrors.related_job_middle_category_ids ?? []),
  ];

  // 工程の、メイン（メインで担当する工程）とサブ（関われる工程）の番号の一覧と、まとめたエラー（職種と同じ形）
  const workProcessRoleIds: RoleIds = {
    main: values.main_work_process_ids,
    sub: values.involved_work_process_ids,
  };
  const workProcessErrors = [
    ...(fieldErrors.main_work_process_ids ?? []),
    ...(fieldErrors.involved_work_process_ids ?? []),
  ];

  // カルチャーの5軸を、スライダーの部品に渡す「軸の名前 → 数」の形に直す。Rails のエラー（culture_pace など）も軸ごとに渡す
  const cultureValues: Record<string, number> = {};
  const cultureErrors: FieldErrors = {};
  for (const axis of options.culture_axes) {
    const key = cultureKeyOf(axis.key);
    if (!key) continue;
    cultureValues[axis.key] = values[key];
    const messages = fieldErrors[key];
    if (messages) cultureErrors[axis.key] = messages;
  }

  // 新規作成のときは「終了」を選べない（権限_バリデーション.md の 17-2-2。Rails も確かめる）
  const statusOptions = options.enums.job_posting_status.filter(
    (option) => !(isNew && option.value === "closed"),
  );

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
      hasError: section.fields.some((field) => fieldErrors[field] !== undefined),
    };
  }

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <PageTitle>{isNew ? "募集新規作成" : "募集詳細編集"}</PageTitle>
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
            <SelectField
              {...textProps("status")}
              label="募集状態"
              required
              choices={statusOptions}
              description="非公開の募集は学生に見えません。書きかけの保存にも使えます"
            />

            <Field>
              <FieldLabel>会社名</FieldLabel>
              <p className="text-sm">{company?.name ?? ""}</p>
              <FieldDescription>会社情報で変更できます</FieldDescription>
            </Field>

            <TextField {...textProps("title")} label="募集タイトル" required />
          </FormSection>

          {/* 業界・事業形態（任意）。会社情報の値とは別に持ち、空欄でも会社情報の値で補わない（その他決め事.md の 5-8） */}
          <FormSection {...sectionProps("industries")}>
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
          </FormSection>

          <FormSection {...sectionProps("job_categories")}>
            {/* 1つの一覧で選び、チェックを入れた中分類の横で「メイン｜サブ」を切り替える（PR234）。
                チェックを入れた時点ではメイン（lib/role-ids.ts の withSelectedIds） */}
            <JobCategoryPicker
              name="job-category"
              legend="職種"
              majors={options.masters.job_major_categories}
              selectedIds={selectedIdsOf(jobCategoryRoleIds)}
              onChange={(ids) => updateJobCategories(withSelectedIds(jobCategoryRoleIds, ids))}
              errors={jobCategoryErrors.length > 0 ? jobCategoryErrors : undefined}
              roles={{
                choices: JOB_CATEGORY_ROLES,
                roleOf: (id) => roleOf(jobCategoryRoleIds, id),
                onRoleChange: (id, role) => updateJobCategories(withRole(jobCategoryRoleIds, id, role)),
              }}
            />
          </FormSection>

          <FormSection {...sectionProps("work_processes")}>
            <WorkProcessPicker
              workProcesses={options.masters.work_processes}
              value={workProcessRoleIds}
              onChange={(roleIds) =>
                setValues((current) =>
                  current
                    ? { ...current, main_work_process_ids: roleIds.main, involved_work_process_ids: roleIds.sub }
                    : current,
                )
              }
              errors={workProcessErrors.length > 0 ? workProcessErrors : undefined}
            />
          </FormSection>

          <FormSection {...sectionProps("overview")}>
            <LongTextField
              {...textProps("about")}
              label="どんな会社か"
              description="空欄なら、会社情報の内容を表示します"
              placeholder={company?.about ?? undefined}
            />
            <LongTextField
              {...textProps("business_description")}
              label="事業内容"
              description="空欄なら、会社情報の内容を表示します"
              placeholder={company?.business_description ?? undefined}
            />
            <LongTextField {...textProps("internship_details")} label="インターンですること（掲載に必要）" />
            <LongTextField {...textProps("growth")} label="成長イメージ" />
          </FormSection>

          <FormSection {...sectionProps("requirements")}>
            <LongTextField {...textProps("requirements")} label="必須要件" />
            <LongTextField {...textProps("preferred_requirements")} label="歓迎要件" />

            {/* 使用技術：区分ごとに開閉できる行にし、選んでいる件数を行に出す（募集一覧の検索の条件と共通の部品） */}
            <TechnologyPicker
              name="technology"
              legend="使用言語・フレームワーク・技術"
              options={options}
              selectedIds={values.technology_ids}
              onChange={(ids) => updateValue("technology_ids", ids)}
              errors={fieldErrors.technology_ids}
            />

            <LongTextField
              {...textProps("technology_note")}
              label="使用技術の補足"
              description="一覧にない技術や、使い方の説明など"
            />
          </FormSection>

          <FormSection {...sectionProps("wage")}>
            <Field data-invalid={fieldErrors.hourly_wage ? true : undefined}>
              <FieldLabel htmlFor="hourly_wage">時給（掲載に必要）</FieldLabel>
              <div className="flex items-center gap-2">
                <Input
                  id="hourly_wage"
                  inputMode="numeric"
                  className="w-40"
                  value={values.hourly_wage}
                  onChange={(event) => updateValue("hourly_wage", event.target.value)}
                  aria-invalid={fieldErrors.hourly_wage ? true : undefined}
                />
                <span className="text-sm">円</span>
              </div>
              <FieldError errors={toFieldErrorItems(fieldErrors.hourly_wage)} />
            </Field>
          </FormSection>

          {/* 稼働条件はすべて任意（その他決め事.md の 5-6） */}
          <FormSection {...sectionProps("work_conditions")}>
            <SelectField
              {...textProps("min_work_days_per_week")}
              label="週の稼働日数"
              emptyLabel="指定なし"
              choices={options.work_conditions.work_days_per_week.map((days) => ({
                value: String(days),
                label: `週${days}日以上`,
              }))}
            />
            <SelectField
              {...textProps("min_work_hours_per_day")}
              label="1日の稼働時間"
              emptyLabel="指定なし"
              choices={options.work_conditions.work_hours_per_day.map((hours) => ({
                value: String(hours),
                label: `1日${hours}時間以上`,
              }))}
            />
            <SelectField
              {...textProps("min_duration_months")}
              label="継続期間"
              emptyLabel="指定なし"
              choices={options.work_conditions.duration_months.map((months) => ({
                value: String(months),
                label: `${months}ヶ月以上`,
              }))}
            />

            {/* 開始時期：年と月の2つの選択欄。両方空欄なら随時。年の選択肢は1年前〜2年後（ページ設計.md の 6-5 C3） */}
            <MonthField
              id="start_year"
              label="開始時期"
              year={values.start_year}
              month={values.start_month_number}
              onYearChange={(value) => updateValue("start_year", value)}
              onMonthChange={(value) => updateValue("start_month_number", value)}
              years={yearChoices(currentYear - 1, currentYear + 2, values.start_year)}
              errors={fieldErrors.start_month}
              description="両方空欄なら「随時」になります"
            />

            <SelectField
              {...textProps("work_style")}
              label="勤務形態"
              emptyLabel="選択してください"
              choices={options.enums.work_style}
            />
            <TextField {...textProps("work_style_note")} label="勤務形態の補足" />

            <SelectField
              {...textProps("prefecture_id")}
              label="勤務地"
              emptyLabel="選択してください"
              choices={options.masters.prefectures.map((prefecture) => ({
                value: String(prefecture.id),
                label: prefecture.name,
              }))}
            />
            <TextField {...textProps("work_location_note")} label="最寄り駅など" />

            <Field orientation="horizontal">
              <Checkbox
                id="weekend_ok"
                checked={values.weekend_ok}
                onCheckedChange={(checked) => updateValue("weekend_ok", checked)}
              />
              <FieldLabel htmlFor="weekend_ok" className="font-normal">
                土日OK
              </FieldLabel>
            </Field>

            <LongTextField {...textProps("work_note")} label="稼働条件の備考" />
          </FormSection>

          {/* カルチャーグラフ。学生の働き方の好みと同じ5軸・同じ部品（その他決め事.md の 5-5） */}
          <FormSection {...sectionProps("culture")}>
            <CultureAxesField
              legend="カルチャー"
              axes={options.culture_axes}
              values={cultureValues}
              onChange={(axisKey, value) => {
                const key = cultureKeyOf(axisKey);
                if (key) updateValue(key, value);
              }}
              errors={cultureErrors}
            />
          </FormSection>

          {/* この募集に近いプチ職業体験（任意、複数。PR374）。選んだ講座は、学生の募集詳細の枠に出る */}
          <FormSection {...sectionProps("job_trials")}>
            <JobTrialCheckboxGroup
              jobTrials={options.masters.job_trials}
              selectedIds={values.job_trial_ids}
              onChange={(ids) => updateValue("job_trial_ids", ids)}
              errors={fieldErrors.job_trial_ids}
            />
          </FormSection>
        </Accordion>

        <div className="flex items-center gap-4">
          <Button type="submit">{saving ? "保存中…" : "保存"}</Button>
          <Link href="/company/job_postings" className={buttonVariants({ variant: "outline" })}>
            募集一覧へ戻る
          </Link>
        </div>
      </form>
    </div>
  );
}
