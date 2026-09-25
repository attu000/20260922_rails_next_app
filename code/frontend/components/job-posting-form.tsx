"use client";

// 募集詳細編集（C3）の入力フォーム。新規作成と編集で同じものを使う。
// 詳しくは design/designs/ページ設計.md の 6-5 C3、API設計.md の 16-3 ⑦⑧⑫⑬⑭。
// 開いたら ⑦ 選択肢と ⑧ 自社のプロフィール（会社名と、空欄のときに薄く出す値）を取り、編集なら ⑫ 募集1件も取る。
// 保存は、新規なら ⑬、編集なら ⑭ を送り、成功したら募集一覧へ戻る。
// 入力欄は6つのまとまり（基本・職種・募集概要・要件と使用技術・給与・稼働条件）に分け、見出しの行を押すと開く形（アコーディオン）にしている。
// 必須は2段（その他決め事.md の 5-9）：常に必須は状態・タイトル。インターンですること・時給は「掲載に必要」（状態が掲載中のときだけ必須）。
// 工程・業界・事業形態・カルチャーグラフは順9（【強み】）、目的・求める人材は【仕上げ】で足す

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import { JobCategoryPicker } from "@/components/job-category-picker";
import { MasterCheckboxGroup } from "@/components/master-checkbox-group";
import { useRedirectIfUnauthorized } from "@/components/member-only";
import { PageTitle } from "@/components/page-title";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { Button, buttonVariants } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Field, FieldDescription, FieldError, FieldGroup, FieldLabel, FieldLegend, FieldSet } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { NativeSelect, NativeSelectOption } from "@/components/ui/native-select";
import { Textarea } from "@/components/ui/textarea";
import { ApiError, apiFetch, useApi } from "@/lib/api";
import type { JobPosting } from "@/lib/job-postings";
import { useOptions } from "@/lib/options";

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
  technology_ids: number[];
};

// 文字の入力欄の名前
type TextKey = {
  [K in keyof FormValues]: FormValues[K] extends string ? K : never;
}[keyof FormValues];

// 項目ごとのエラー。Rails の 422 の errors と同じ形（例：{ title: ["募集タイトルを入力してください"] }）
type FieldErrors = Record<string, string[]>;

// 形式と長さの決まり。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）
const SHORT_TEXT_MAX_LENGTH = 100;
const LONG_TEXT_MAX_LENGTH = 2000;
const HOURLY_WAGE_MAX = 100000;

// 項目名。その場での確認の文言を、Rails と同じ「項目名＋理由」の形にするために使う（config/locales/ja.yml と同じ）
const SHORT_TEXT_LABELS = {
  title: "募集タイトル",
  work_style_note: "勤務形態の補足",
  work_location_note: "最寄り駅など",
} as const satisfies Partial<Record<TextKey, string>>;

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
  technology_ids: [],
};

// 開始時期の月の選択肢（1〜12月）
const MONTH_NUMBERS = Array.from({ length: 12 }, (_, index) => String(index + 1));

// フォームのまとまり。見出しの行を押すと中身が開く（アコーディオン）。並びはこの順。
// fields は、そのまとまりに入っている項目の名前（エラーのときに、どのまとまりを開くかを決めるのに使う。Rails の errors のキーと同じ）
const SECTIONS = [
  { value: "basic", title: "基本", hint: "募集状態・タイトル（必須）", fields: ["status", "title"] },
  {
    value: "job_categories",
    title: "職種",
    hint: "主な職種・関連する職種",
    fields: ["main_job_middle_category_ids", "related_job_middle_category_ids"],
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
] as const;

type SectionValue = (typeof SECTIONS)[number]["value"];

// 最初に開いておくまとまり（新規・編集とも「基本」だけ）
const INITIAL_OPEN_SECTIONS: SectionValue[] = ["basic"];

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

function toText(value: string | number | null): string {
  return value === null ? "" : String(value);
}

function toNumberOrNull(value: string): number | null {
  return value.trim() === "" ? null : Number(value);
}

// ⑫ の返事を、フォームの値に直す
function toFormValues(posting: JobPosting): FormValues {
  // "2026-10-01" → 年 "2026"、月 "10"
  const [year, month] = posting.start_month ? posting.start_month.split("-") : ["", ""];
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
    start_month_number: month ? String(Number(month)) : "",
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
    technology_ids: posting.technology_ids,
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
    start_month: startYear && startMonthNumber ? `${startYear}-${startMonthNumber.padStart(2, "0")}-01` : null,
    work_style: values.work_style === "" ? null : values.work_style,
    prefecture_id: toNumberOrNull(values.prefecture_id),
    hourly_wage: toNumberOrNull(values.hourly_wage),
  };
}

// 今年（日本時間で数える。API設計.md の 16-1-12）
function currentYearInTokyo(): number {
  return Number(new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Tokyo", year: "numeric" }).format(new Date()));
}

// 開始時期の年の選択肢：1年前〜2年後。保存済みの年がその範囲の外なら、その年も足す（ページ設計.md の 6-5 C3）
function startYearOptions(currentYear: number, savedYear: string): string[] {
  const years = [currentYear - 1, currentYear, currentYear + 1, currentYear + 2].map(String);
  if (savedYear !== "" && !years.includes(savedYear)) {
    years.push(savedYear);
    years.sort();
  }
  return years;
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
  if ((values.start_year === "") !== (values.start_month_number === "")) {
    errors.start_month = ["開始時期は年と月の両方を選んでください"];
  }

  return errors;
}

// FieldError に渡す形に直す
function toFieldErrorItems(messages: string[] | undefined) {
  return messages?.map((message) => ({ message }));
}

// 入力欄の部品が共通で受け取るもの。フォームの中の textProps() で作って渡す
type InputProps = {
  id: string;
  value: string;
  onChange: (value: string) => void;
  errors: string[] | undefined;
};

// 文字の入力欄（1行）。見出し・入力欄・文字数・エラーの組み立てを使い回す。
// 部品はフォームの外に置く（フォームの中で定義すると、描き直すたびに入力欄が作り直され、打っている途中でカーソルが外れるため）
function TextField({ id, value, onChange, errors, label }: InputProps & { label: string }) {
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

// 文章の入力欄（複数行）。placeholder は、空欄のときに薄く出す文（どんな会社か・事業内容で、会社情報の内容を出す）
function LongTextField({
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

// 選択欄。選択肢と表示名は Rails が返したものだけを使う（16-1-9）
function SelectField({
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

// まとまり1つ分。四角い見出しの行（題名と一言、エラーがあれば「要確認」）と、押すと下に開く中身。
// 閉じている間も中身は消さずに隠すだけにする（keepMounted）。職種の開閉などの状態を、閉じても覚えておくため
function FormSection({
  value,
  title,
  hint,
  hasError,
  children,
}: {
  value: SectionValue;
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
      <PageTitle>{isNew ? "募集新規作成" : "募集詳細編集"}</PageTitle>

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
              label="募集状態（必須）"
              choices={statusOptions}
              description="非公開の募集は学生に見えません。書きかけの保存にも使えます"
            />

            <Field>
              <FieldLabel>会社名</FieldLabel>
              <p className="text-sm">{company?.name ?? ""}</p>
              <FieldDescription>会社情報で変更できます</FieldDescription>
            </Field>

            <TextField {...textProps("title")} label="募集タイトル（必須）" />
          </FormSection>

          <FormSection {...sectionProps("job_categories")}>
            <JobCategoryPicker
              name="main-job-category"
              legend="主な職種"
              majors={options.masters.job_major_categories}
              selectedIds={values.main_job_middle_category_ids}
              disabledIds={values.related_job_middle_category_ids}
              disabledNote="関連する職種で選択済み"
              onChange={(ids) => updateValue("main_job_middle_category_ids", ids)}
              errors={fieldErrors.main_job_middle_category_ids}
            />
            <JobCategoryPicker
              name="related-job-category"
              legend="関連する職種"
              majors={options.masters.job_major_categories}
              selectedIds={values.related_job_middle_category_ids}
              disabledIds={values.main_job_middle_category_ids}
              disabledNote="主な職種で選択済み"
              onChange={(ids) => updateValue("related_job_middle_category_ids", ids)}
              errors={fieldErrors.related_job_middle_category_ids}
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

            {/* 使用技術：区分ごとに開閉できる行にし、選んでいる件数を行に出す。中は順1 のチェックボックスの部品を使い回す */}
            <FieldSet>
              <FieldLegend variant="label">使用言語・フレームワーク・技術</FieldLegend>
              <Accordion multiple className="gap-2">
                {options.enums.technology_category.map((category) => {
                  const rows = options.masters.technologies.filter(
                    (technology) => technology.category === category.value,
                  );
                  const selectedCount = rows.filter((row) => values.technology_ids.includes(row.id)).length;
                  return (
                    <AccordionItem key={category.value} value={category.value} className="rounded-lg border">
                      <AccordionTrigger className="items-center px-3 py-2 hover:no-underline">
                        <span>{category.label}</span>
                        {selectedCount > 0 && (
                          <span className="mr-2 ml-auto text-xs font-normal text-muted-foreground">
                            {selectedCount}件選択中
                          </span>
                        )}
                      </AccordionTrigger>
                      <AccordionContent keepMounted className="px-3 pb-3">
                        <MasterCheckboxGroup
                          name={`technology-${category.value}`}
                          legend={category.label}
                          hideLegend
                          rows={rows}
                          selectedIds={values.technology_ids}
                          onChange={(ids) => updateValue("technology_ids", ids)}
                        />
                      </AccordionContent>
                    </AccordionItem>
                  );
                })}
              </Accordion>
              <FieldError errors={toFieldErrorItems(fieldErrors.technology_ids)} />
            </FieldSet>

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

            {/* 開始時期：年と月の2つの選択欄。両方空欄なら随時（ページ設計.md の 6-5 C3） */}
            <Field data-invalid={fieldErrors.start_month ? true : undefined}>
              <FieldLabel htmlFor="start_year">開始時期</FieldLabel>
              <div className="flex items-center gap-2">
                <NativeSelect
                  id="start_year"
                  value={values.start_year}
                  onChange={(event) => updateValue("start_year", event.target.value)}
                  aria-invalid={fieldErrors.start_month ? true : undefined}
                >
                  <NativeSelectOption value="">―</NativeSelectOption>
                  {startYearOptions(currentYear, values.start_year).map((year) => (
                    <NativeSelectOption key={year} value={year}>
                      {year}年
                    </NativeSelectOption>
                  ))}
                </NativeSelect>
                <NativeSelect
                  aria-label="開始時期の月"
                  value={values.start_month_number}
                  onChange={(event) => updateValue("start_month_number", event.target.value)}
                  aria-invalid={fieldErrors.start_month ? true : undefined}
                >
                  <NativeSelectOption value="">―</NativeSelectOption>
                  {MONTH_NUMBERS.map((month) => (
                    <NativeSelectOption key={month} value={month}>
                      {month}月
                    </NativeSelectOption>
                  ))}
                </NativeSelect>
                <span className="text-sm">から</span>
              </div>
              <FieldDescription>両方空欄なら「随時」になります</FieldDescription>
              <FieldError errors={toFieldErrorItems(fieldErrors.start_month)} />
            </Field>

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
