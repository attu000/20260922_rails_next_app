// 学生プロフィールの入力欄と、値の変換・その場の確認。
// マイページ（S1）と、学生の新規登録（S9）のステップ2〜7で使い回す
// （design/designs/ページ設計.md の 6-6 S1・S9、API設計.md の 16-3 ⑮⑯⑥）。
// マイページと登録では欄のまとまり方が違うので、欄を小さな部品に分け、使う側が並べる。
// 氏名とアイコンは、登録ではステップ1と最後のステップに分かれるので、ここには入れない（会社情報の部品と同じ）。
// 外部リンク・資格・就活希望エリアは【仕上げ】で足す（興味のある業界は順10 で前倒しした。PR254）

import { CultureAxesField } from "@/components/culture-axes-field";
import {
  LONG_TEXT_MAX_LENGTH,
  LongTextField,
  MonthField,
  SHORT_TEXT_MAX_LENGTH,
  SelectField,
  TextField,
  toFieldErrorItems,
  type FieldErrors,
  type InputProps,
} from "@/components/form-fields";
import { JobCategoryPicker } from "@/components/job-category-picker";
import { MasterCheckboxGroup } from "@/components/master-checkbox-group";
import { toSkillRequest, toSkillRows, validateSkillRows, type SkillRow } from "@/components/skill-rows-field";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { Checkbox } from "@/components/ui/checkbox";
import { Field, FieldError, FieldLabel, FieldLegend, FieldSet } from "@/components/ui/field";
import {
  isHalfSelectedMonth,
  joinMonthDate,
  splitMonthDate,
  toNumberOrNull,
  toStringOrNull,
  toText,
  yearChoices,
} from "@/lib/form-values";
import type { Options } from "@/lib/options";
import type { StudentProfile } from "@/lib/student-profile";

// 大学の選択欄で「その他（一覧にない大学）」を表す値
const OTHER_UNIVERSITY = "other";

// 働き方の好み（性格）の5軸の項目名。Rails の列名・エラーのキーと同じ。
// マイページのまとまりと新規登録のステップが、Rails のエラーからどこを開くかを決めるのにも使う
export const PERSONALITY_KEYS = [
  "personality_pace",
  "personality_novelty",
  "personality_collaboration",
  "personality_decision",
  "personality_atmosphere",
] as const;

type PersonalityKey = (typeof PERSONALITY_KEYS)[number];

// 学生プロフィールの値（氏名を除く）。入力欄にそのまま入れるため、空欄は "" で持つ（選択欄の数値も文字で持つ）。
// 大学は「一覧の大学の番号」か「その他」を1つの選択欄で持ち、開始時期は年と月の2つの選択欄に分けて持つ
export type StudentProfileValues = {
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
  interested_industry_ids: number[];
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
  // 働き方の好みの5軸は、スライダーの位置（−2〜2）を数のまま持つ（空欄がないため）
  personality_pace: number;
  personality_novelty: number;
  personality_collaboration: number;
  personality_decision: number;
  personality_atmosphere: number;
  skills: SkillRow[];
};

// 何も入れていない値（新規登録の最初）。データベースの既定値と同じ（データベース.md の 8-5）。
// 勤務形態の3つは「可能」、働き方の好みの5軸は真ん中（0）
export const EMPTY_STUDENT_PROFILE: StudentProfileValues = {
  activity_status: "",
  prefecture_id: "",
  university: "",
  university_other_name: "",
  faculty_id: "",
  department_id: "",
  grade: "",
  self_pr_strength: "",
  self_pr_weakness: "",
  self_pr_future: "",
  graduation_year: "",
  interested_industry_ids: [],
  interested_job_middle_category_ids: [],
  work_days_per_week: "",
  work_hours_per_day: "",
  duration_months: "",
  available_year: "",
  available_month: "",
  can_full_remote: true,
  can_partial_remote: true,
  can_onsite: true,
  commutable_prefecture_ids: [],
  work_note: "",
  personality_pace: 0,
  personality_novelty: 0,
  personality_collaboration: 0,
  personality_decision: 0,
  personality_atmosphere: 0,
  skills: [],
};

// 文字の入力欄の名前
type TextKey = {
  [K in keyof StudentProfileValues]: StudentProfileValues[K] extends string ? K : never;
}[keyof StudentProfileValues];

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

// ⑮ の返事を、フォームの値に直す（氏名を除く）
export function toStudentProfileValues(profile: StudentProfile): StudentProfileValues {
  // 一覧の大学がなく「その他」の名前があれば、選択欄は「その他」
  const university =
    profile.university_id !== null
      ? String(profile.university_id)
      : profile.university_other_name
        ? OTHER_UNIVERSITY
        : "";
  const { year, month } = splitMonthDate(profile.available_from);
  return {
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
    interested_industry_ids: profile.interested_industry_ids,
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
    personality_pace: profile.personality_pace,
    personality_novelty: profile.personality_novelty,
    personality_collaboration: profile.personality_collaboration,
    personality_decision: profile.personality_decision,
    personality_atmosphere: profile.personality_atmosphere,
    skills: toSkillRows(profile.skills),
  };
}

// フォームの値を、⑯（マイページ）・⑥（新規登録）に送る形に直す（氏名を除く）。フォームの全項目を送る（API設計.md の 16-3 ⑯）。
// 空欄の数値・選択は null。空欄の文章は "" のまま送る（Rails が null にそろえる）
export function toStudentProfileRequest(values: StudentProfileValues) {
  const isOtherUniversity = values.university === OTHER_UNIVERSITY;
  return {
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
    interested_industry_ids: values.interested_industry_ids,
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
    personality_pace: values.personality_pace,
    personality_novelty: values.personality_novelty,
    personality_collaboration: values.personality_collaboration,
    personality_decision: values.personality_decision,
    personality_atmosphere: values.personality_atmosphere,
    skills: toSkillRequest(values.skills),
  };
}

// その場で分かる確認だけを行う（権限_バリデーション.md の 17-3-2）。氏名とアイコンの確認は、使う側が行う。
// Rails も同じ確認をするので、ここをすり抜けても守られる。
// 文言は Rails と同じにする（開始時期の「年と月の両方」と、「大学名を入力してください」は画面側だけの文言。17-3-6）
export function validateStudentProfile(values: StudentProfileValues): FieldErrors {
  const errors: FieldErrors = {};

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

  return { ...errors, ...validateSkillRows(values.skills) };
}

// ── 入力欄の部品 ──
// どれも同じものを受け取る。onChange には、変えた項目と値の組（例：{ grade: "undergrad_3" }）を渡す（会社情報の部品と同じ形）

export type StudentFieldsProps = {
  values: StudentProfileValues;
  onChange: (change: Partial<StudentProfileValues>) => void;
  errors: FieldErrors;
  options: Options;
};

// 今年（卒業年度・開始時期の選択肢に使う）。使う側が、画面を開いたときに1回だけ数えて渡す
type WithCurrentYear = { currentYear: number };

// 「この項目をこの値に変えた」という組を作る（例：changeOf("grade", "undergrad_3") → { grade: "undergrad_3" }）。
// { [key]: value } と書くと、TypeScript が項目と値の型の対応を見失うので、1つずつ入れる形にしている
function changeOf<K extends keyof StudentProfileValues>(key: K, value: StudentProfileValues[K]): Partial<StudentProfileValues> {
  const change: Partial<StudentProfileValues> = {};
  change[key] = value;
  return change;
}

// 文字の入力欄の部品に渡す値・変更の関数・エラーを、項目の名前からまとめて作る
function textProps({ values, onChange, errors }: StudentFieldsProps, name: TextKey): InputProps {
  return {
    id: name,
    value: values[name],
    onChange: (value: string) => onChange(changeOf(name, value)),
    errors: errors[name],
  };
}

// マスタの行を、選択欄の選択肢の形に直す
function toChoices(rows: { id: number; name: string }[]) {
  return rows.map((row) => ({ value: String(row.id), label: row.name }));
}

// 活動状況（必須）
export function ActivityStatusField(props: StudentFieldsProps) {
  return (
    <SelectField
      {...textProps(props, "activity_status")}
      label="活動状況"
      required
      emptyLabel="選択してください"
      choices={props.options.enums.activity_status}
      description="「今は探していない」を選んでも、企業の学生検索には表示されます"
    />
  );
}

// 在住の都道府県
export function ResidencePrefectureField(props: StudentFieldsProps) {
  return (
    <SelectField
      {...textProps(props, "prefecture_id")}
      label="在住の都道府県"
      emptyLabel="選択してください"
      choices={toChoices(props.options.masters.prefectures)}
    />
  );
}

// 大学（その他なら大学名）・学部・学科・学年
export function StudentSchoolFields(props: StudentFieldsProps) {
  const { values, onChange, errors, options } = props;
  // 選んでいる学部の学科（学部を選ぶまでは空）
  const departments =
    options.masters.faculties.find((faculty) => String(faculty.id) === values.faculty_id)?.departments ?? [];

  return (
    <>
      {/* 大学の選択欄のエラーは、一覧の大学の番号（university_id）のもの */}
      <SelectField
        {...textProps(props, "university")}
        errors={errors.university_id}
        label="大学"
        emptyLabel="選択してください"
        choices={[...toChoices(options.masters.universities), { value: OTHER_UNIVERSITY, label: "その他（一覧にない大学）" }]}
      />
      {/* 「その他」を選んだときだけ、大学名の入力欄を出す（海外の大学など） */}
      {values.university === OTHER_UNIVERSITY && <TextField {...textProps(props, "university_other_name")} label="大学名" />}
      <SelectField
        {...textProps(props, "faculty_id")}
        // 学部を変えたら、学科を空に戻す（学科は学部ごとの一覧から選ぶため）
        onChange={(facultyId) => onChange({ faculty_id: facultyId, department_id: "" })}
        label="学部"
        emptyLabel="選択してください"
        choices={toChoices(options.masters.faculties)}
      />
      <SelectField
        {...textProps(props, "department_id")}
        label="学科"
        emptyLabel={values.faculty_id === "" ? "先に学部を選んでください" : "選択してください"}
        choices={toChoices(departments)}
      />
      <SelectField {...textProps(props, "grade")} label="学年" emptyLabel="選択してください" choices={options.enums.grade} />
    </>
  );
}

// 卒業年度。選択肢は今年〜10年後。保存済みの年がその外なら足す（Rails 側は範囲を制限しない。ページ設計.md の 6-6 S1）
export function GraduationYearField(props: StudentFieldsProps & WithCurrentYear) {
  const { values, currentYear } = props;
  return (
    <SelectField
      {...textProps(props, "graduation_year")}
      label="卒業年度"
      emptyLabel="選択してください"
      choices={yearChoices(currentYear, currentYear + 10, values.graduation_year).map((year) => ({
        value: year,
        label: `${year}年卒`,
      }))}
    />
  );
}

// 興味のある業界（PR254）。会社プロフィール・募集詳細編集の業界と同じ、マスタのチェック欄の部品
export function InterestedIndustriesField({ values, onChange, errors, options }: StudentFieldsProps) {
  return (
    <MasterCheckboxGroup
      name="interested-industry"
      legend="興味のある業界"
      rows={options.masters.industries}
      selectedIds={values.interested_industry_ids}
      onChange={(ids) => onChange({ interested_industry_ids: ids })}
      errors={errors.interested_industry_ids}
    />
  );
}

// 興味のある職種
export function InterestedJobCategoriesField({ values, onChange, errors, options }: StudentFieldsProps) {
  return (
    <JobCategoryPicker
      name="interested-job-category"
      legend="興味のある職種"
      majors={options.masters.job_major_categories}
      selectedIds={values.interested_job_middle_category_ids}
      onChange={(ids) => onChange({ interested_job_middle_category_ids: ids })}
      errors={errors.interested_job_middle_category_ids}
    />
  );
}

// 稼働条件。すべて任意。学生は「無理なく出せる量（上限）」を入れる（その他決め事.md の 5-6）
export function StudentWorkConditionFields(props: StudentFieldsProps & WithCurrentYear) {
  const { values, onChange, errors, options, currentYear } = props;
  const commutableCount = values.commutable_prefecture_ids.length;

  return (
    <>
      <SelectField
        {...textProps(props, "work_days_per_week")}
        label="週の稼働日数"
        emptyLabel="指定なし"
        choices={options.work_conditions.work_days_per_week.map((days) => ({
          value: String(days),
          label: `週${days}日まで`,
        }))}
      />
      <SelectField
        {...textProps(props, "work_hours_per_day")}
        label="1日の稼働時間"
        emptyLabel="指定なし"
        choices={options.work_conditions.work_hours_per_day.map((hours) => ({
          value: String(hours),
          label: `1日${hours}時間まで`,
        }))}
      />
      <SelectField
        {...textProps(props, "duration_months")}
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
        onYearChange={(value) => onChange({ available_year: value })}
        onMonthChange={(value) => onChange({ available_month: value })}
        years={yearChoices(currentYear - 1, currentYear + 2, values.available_year)}
        errors={errors.available_from}
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
                onCheckedChange={(checked) => onChange(changeOf(check.key, checked))}
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
                <span className="mr-2 ml-auto text-xs font-normal text-muted-foreground">{commutableCount}件選択中</span>
              )}
            </AccordionTrigger>
            <AccordionContent keepMounted className="px-3 pb-3">
              <MasterCheckboxGroup
                name="commutable-prefecture"
                legend="出社できる都道府県"
                hideLegend
                rows={options.masters.prefectures}
                selectedIds={values.commutable_prefecture_ids}
                onChange={(ids) => onChange({ commutable_prefecture_ids: ids })}
              />
            </AccordionContent>
          </AccordionItem>
        </Accordion>
        {/* エラーは開閉する行の外に出す（閉じたままでも見えるように） */}
        <FieldError errors={toFieldErrorItems(errors.commutable_prefecture_ids)} />
      </FieldSet>

      <LongTextField {...textProps(props, "work_note")} label="稼働条件の備考" placeholder="例：テスト期間は稼働を減らしたい" />
    </>
  );
}

// 軸の名前（"pace"）から、働き方の好みの項目名（"personality_pace"）を引く。知らない軸なら undefined
function personalityKeyOf(axisKey: string): PersonalityKey | undefined {
  return PERSONALITY_KEYS.find((key) => key === `personality_${axisKey}`);
}

// 働き方の好み（性格の5軸。PR233）。5本のスライダーの部品に、「軸の名前 → 数」に直して渡す
export function WorkStylePreferenceField({ values, onChange, errors, options }: StudentFieldsProps) {
  const axisValues: Record<string, number> = {};
  const axisErrors: FieldErrors = {};
  for (const axis of options.culture_axes) {
    const key = personalityKeyOf(axis.key);
    if (!key) continue;
    axisValues[axis.key] = values[key];
    // Rails のエラー（personality_pace など）を、軸ごとに渡す
    const messages = errors[key];
    if (messages) axisErrors[axis.key] = messages;
  }

  return (
    <CultureAxesField
      legend="働き方の好み"
      axes={options.culture_axes}
      values={axisValues}
      onChange={(axisKey, value) => {
        const key = personalityKeyOf(axisKey);
        if (key) onChange(changeOf(key, value));
      }}
      errors={axisErrors}
    />
  );
}

// 自己PRの3つの問い
export function StudentSelfPrFields(props: StudentFieldsProps) {
  return (
    <>
      <LongTextField {...textProps(props, "self_pr_strength")} label="自分の強み、向いていること" />
      <LongTextField {...textProps(props, "self_pr_weakness")} label="向いていないこと" />
      <LongTextField {...textProps(props, "self_pr_future")} label="この先やりたいこと、挑戦したいこと" />
    </>
  );
}
