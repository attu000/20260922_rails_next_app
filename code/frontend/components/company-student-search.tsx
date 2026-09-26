"use client";

// 学生検索（C5）の中身。詳しくは design/designs/ページ設計.md の 6-5 C5、API設計.md の 16-3 ㉒・16-1-11。
//
// 選んだ募集・並び順・条件・ページは、すべて URL の ? の後ろに持つ（URL が正。16-1-13）。
// - 条件欄は [稼働条件][技術][職種][学年・卒業年度・活動状況](フリーワード)[検索する] の横並び。各ボタンはポップアップを開く
//   （募集一覧（学生のホーム）と同じ形。PR201）
// - 条件欄を触っても、画面の中の下書きが変わるだけ。「検索する」を押したときに URL に書き込む（PR192）
// - 募集と並び順は、選んだらすぐ URL に書き込む（募集検索の並び順と同じ扱い。PR196）。条件はそのまま残す
// - URL が変わると SWR が Rails に取りに行く。ブラウザの「戻る」で、条件欄も結果も前の URL の内容に戻る
//
// 結果は条件で減らさず、合致の群を先に、合致外の群をあとに並べて返ってくる（Rails が並べる）。
// 画面は、合致外に変わるところに「ここから条件に合いません」の区切りを入れるだけ（処理設計_類似度.md の 7-3）。
// 30日以上活動のない学生と、もうスカウトした・見送った・マッチした学生は、Rails が外して返す（PR216・PR220）。
// 行には、その募集とのやりとり（未対応応募）か、自社とのやりとりがあることを札で出す（PR219）。
// 次のものは、それを作る順で足す
//   - 募集を選ぶと、その募集の稼働条件で条件欄が自動で入る仕組み：後で（PR214）
//   - 最終活動の目安、フリーワードの資格名：【仕上げ】

import { Fragment, useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import {
  CompanySearchWorkConditions,
  type CompanyWorkConditionsDraft,
  countCompanyWorkConditions,
  EMPTY_COMPANY_WORK_CONDITIONS,
  fromCompanyWorkConditionsDraft,
  toCompanyWorkConditionsDraft,
} from "@/components/company-search-work-conditions";
import { ChoiceButtons } from "@/components/choice-buttons";
import { JobCategoryPicker } from "@/components/job-category-picker";
import { MasterCheckboxGroup } from "@/components/master-checkbox-group";
import { PageNav } from "@/components/page-nav";
import { PageTitle } from "@/components/page-title";
import { ProfileIcon } from "@/components/profile-icon";
import { SearchConditionDialog } from "@/components/search-condition-dialog";
import { StatusBadge } from "@/components/status-badge";
import { TechnologyPicker } from "@/components/technology-picker";
import { Button, buttonVariants } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Field, FieldDescription, FieldGroup, FieldLabel, FieldLegend, FieldSet } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { NativeSelect, NativeSelectOption } from "@/components/ui/native-select";
import { useApi } from "@/lib/api";
import {
  buildStudentSearchQuery,
  type CompanyStudentRow,
  type CompanyStudentSearchResult,
  type StudentSearchConditions,
  type StudentSearchSort,
  type StudentSearchState,
  studentSearchStateFromQuery,
} from "@/lib/company-students";
import { currentYearInTokyo, isHalfSelectedMonth } from "@/lib/form-values";
import type { JobPostingRow } from "@/lib/job-postings";
import { type EnumOption, jobMiddleCategoryNames, labelOf, nameOf, type Options, useOptions } from "@/lib/options";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

const PAGE_PATH = "/company/students";

// ? の後ろ → 画面の URL
function pageUrl(query: string): string {
  return query === "" ? PAGE_PATH : `${PAGE_PATH}?${query}`;
}

export function CompanyStudentSearch() {
  const router = useRouter();
  const searchParams = useSearchParams();
  // URL から読んだ、選んだ募集・並び順・ページ。
  // Rails には、URL をそのままではなく、ここから作り直した ? の後ろを渡す
  // （募集を選ばずにおすすめ順、のような URL を手で書かれても 422 にならないように）
  const state = studentSearchStateFromQuery(searchParams);
  const query = buildStudentSearchQuery(state);

  const { options, failed: optionsFailed } = useOptions();
  // 募集を選ぶ欄に出す自社の募集（⑪ 自社の全募集。候補者一覧のタブと同じ取り方）
  const { data: jobPostings } = useApi<{ items: JobPostingRow[] }>("/api/company/job_postings");
  // 401 は共通の枠（member-only.tsx）がログイン画面へ移す。
  // keepPreviousData：次の結果が届くまで前の結果を出したままにする（ページ送りで画面がちらつかないように）
  const { data, error } = useApi<CompanyStudentSearchResult>(`/api/company/students${query === "" ? "" : `?${query}`}`, {
    keepPreviousData: true,
  });

  // 募集を選ぶ：並び順は既定に戻し（募集を選べばおすすめ順）、1ページ目に戻る。条件はそのまま残す
  function changeJobPosting(jobPostingId: string | null) {
    const sort: StudentSearchSort = jobPostingId === null ? "last_active" : "recommended";
    router.push(pageUrl(buildStudentSearchQuery({ ...state, jobPostingId, sort, page: 1 })));
  }

  // 「検索する」：下書きの条件を URL に書き込む。選んだ募集と並び順はそのまま、1ページ目に戻る
  function search(conditions: StudentSearchConditions) {
    router.push(pageUrl(buildStudentSearchQuery({ ...state, conditions, page: 1 })));
  }

  // 並び順を変える：選んだ募集のまま、1ページ目に戻る
  function changeSort(sort: StudentSearchSort) {
    router.push(pageUrl(buildStudentSearchQuery({ ...state, sort, page: 1 })));
  }

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  if (!options) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  // 選んでいる募集の名前（おすすめ順のタブに出す）。一覧がまだ届いていなければ null
  const selectedTitle =
    jobPostings?.items.find((jobPosting) => String(jobPosting.id) === state.jobPostingId)?.title ?? null;

  return (
    <div className="space-y-6">
      <PageTitle>学生検索</PageTitle>

      <div className="flex flex-wrap items-center gap-2">
        <label htmlFor="search-job-posting" className="text-sm">
          募集を選ぶ
        </label>
        <NativeSelect
          id="search-job-posting"
          value={state.jobPostingId ?? ""}
          onChange={(event) => changeJobPosting(event.target.value || null)}
        >
          <NativeSelectOption value="">選ばない</NativeSelectOption>
          {(jobPostings?.items ?? []).map((jobPosting) => (
            <NativeSelectOption key={jobPosting.id} value={String(jobPosting.id)}>
              {jobPosting.title}
            </NativeSelectOption>
          ))}
        </NativeSelect>
      </div>

      {/* key に URL を渡す：URL が変わったら条件欄を作り直し、下書きを URL の内容に戻す（「戻る」のため） */}
      <SearchForm key={query} initial={state.conditions} options={options} onSearch={search} />

      <SortTabs state={state} selectedTitle={selectedTitle} onChange={changeSort} />

      {!data && error && error.status !== 401 ? (
        // 他社の募集や存在しない募集の番号を URL に入れたときは「見つかりません」
        <p className="text-sm text-destructive">{error.message}</p>
      ) : !data ? (
        <p className="text-sm text-muted-foreground">読み込み中…</p>
      ) : (
        <SearchResults
          result={data}
          options={options}
          jobPostingId={state.jobPostingId}
          hrefFor={(page) => pageUrl(buildStudentSearchQuery({ ...state, page }))}
        />
      )}
    </div>
  );
}

// ── 条件欄 ──
// 部品は、画面の部品の中ではなく、このファイルの一番上の段に置く
// （中で定義すると、描き直すたびに入力欄が作り直され、打っている途中でカーソルが外れるため）

type SearchFormProps = {
  // URL から読んだ条件（下書きの最初の値）
  initial: StudentSearchConditions;
  options: Options;
  onSearch: (conditions: StudentSearchConditions) => void;
};

// 未入力の学生の扱い（各ポップアップに添える。その他決め事.md の 5-10）
const BLANK_NOTE = "学生が未入力の項目は、条件に合わない側に入ります";

function SearchForm({ initial, options, onSearch }: SearchFormProps) {
  const majors = options.masters.job_major_categories;
  // 画面上で保持する条件（下書き）。「検索する」を押すまで Rails には送らない（PR192）
  const [draft, setDraft] = useState<StudentSearchConditions>(initial);
  // チェックを入れている大分類。最初は職種の部品と同じく、URL の大分類と、選んでいる中分類を含む大分類
  const [checkedMajorIds, setCheckedMajorIds] = useState<number[]>(() =>
    majors
      .filter(
        (major) =>
          initial.job_major_category_ids.includes(major.id) ||
          major.job_middle_categories.some((middle) => initial.job_middle_category_ids.includes(middle.id)),
      )
      .map((major) => major.id),
  );
  // 稼働条件の下書き。開始時期は、年と月の片方だけ選んだ状態も持てる形で持つ
  const [workConditions, setWorkConditions] = useState<CompanyWorkConditionsDraft>(() =>
    toCompanyWorkConditionsDraft(initial),
  );
  // 開始時期の確認で見つかったエラー
  const [startMonthErrors, setStartMonthErrors] = useState<string[] | undefined>(undefined);
  // 職種の部品を作り直すための番号。「この条件をクリア」で1つ増やす（募集一覧と同じ。チェックが残って見えないように）
  const [jobCategoryResetKey, setJobCategoryResetKey] = useState(0);

  // 卒業年度の選択肢：マイページと同じ今年〜10年後（ページ設計.md の 6-6 S1）。URL にその外の年があれば、それも足す
  const currentYear = currentYearInTokyo();
  const graduationYears = [
    ...new Set([
      ...Array.from({ length: 11 }, (_, index) => currentYear + index),
      ...draft.graduation_years,
    ]),
  ].sort((a, b) => a - b);

  function updateDraft<K extends keyof StudentSearchConditions>(key: K, value: StudentSearchConditions[K]) {
    setDraft({ ...draft, [key]: value });
  }

  // 中分類を1つも選んでいない大分類（「大分類で探す」として送るもの。募集一覧と同じ）
  const majorOnlyIds = checkedMajorIds.filter((majorId) => {
    const major = majors.find((row) => row.id === majorId);
    return !major?.job_middle_categories.some((middle) => draft.job_middle_category_ids.includes(middle.id));
  });

  function clearJobCategories() {
    setDraft({ ...draft, job_middle_category_ids: [] });
    setCheckedMajorIds([]);
    setJobCategoryResetKey(jobCategoryResetKey + 1);
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    // 開始時期は、年と月の両方を選ぶか、両方空欄にする（画面側だけの確認。募集一覧と同じ文言）
    if (isHalfSelectedMonth(workConditions.start_year, workConditions.start_month)) {
      setStartMonthErrors(["開始時期は年と月の両方を選んでください"]);
      return;
    }
    setStartMonthErrors(undefined);
    onSearch({ ...draft, job_major_category_ids: majorOnlyIds, ...fromCompanyWorkConditionsDraft(workConditions) });
  }

  // 学年・卒業年度・活動状況のボタンに出す数
  const profileCount = draft.grades.length + draft.graduation_years.length + draft.activity_statuses.length;

  // [稼働条件][技術][職種][学年・卒業年度・活動状況](フリーワード)[検索する] を横に並べる。狭い画面では折り返す。
  // 各ボタンを押すとポップアップが開き、中で選んだものはその場で下書きに入る（PR201）
  return (
    <div className="space-y-2">
      <form onSubmit={submit} className="flex flex-wrap items-center gap-2">
        {/* 稼働条件：週の日数、1日の時間、継続期間、開始時期、勤務形態、勤務地 */}
        <SearchConditionDialog
          label="稼働条件"
          count={countCompanyWorkConditions(workConditions)}
          onClear={() => {
            setWorkConditions(EMPTY_COMPANY_WORK_CONDITIONS);
            setStartMonthErrors(undefined);
          }}
          description={`学生が無理なく出せる量（上限）が、選んだ値以上なら条件に合います。${BLANK_NOTE}`}
        >
          <CompanySearchWorkConditions
            options={options}
            draft={workConditions}
            onChange={setWorkConditions}
            startMonthErrors={startMonthErrors}
          />
        </SearchConditionDialog>

        {/* 使用技術とレベル：選んだ技術をすべて持っている学生が合う（募集一覧の「どれか1つ」とは違う。16-3 ㉒） */}
        <SearchConditionDialog
          label="技術"
          count={draft.technology_ids.length + (draft.min_level === null ? 0 : 1)}
          onClear={() => setDraft({ ...draft, technology_ids: [], min_level: null })}
          description={`選んだ技術を、すべてプログラミング歴に持っている学生が条件に合います。${BLANK_NOTE}`}
        >
          <FieldGroup>
            <TechnologyPicker
              name="search-technology"
              legend="言語・フレームワーク・技術"
              options={options}
              selectedIds={draft.technology_ids}
              onChange={(ids) => updateDraft("technology_ids", ids)}
            />
            <SkillLevelChoices
              levels={options.enums.skill_level}
              value={draft.min_level}
              onChange={(value) => updateDraft("min_level", value)}
            />
          </FieldGroup>
        </SearchConditionDialog>

        {/* 職種：大分類 → 中分類。興味のある職種のどれか1つが一致すれば合う。
            ポップアップを閉じると中の部品は消えるので、開き直すときに、覚えている大分類のチェックを渡して元に戻す */}
        <SearchConditionDialog
          label="職種"
          count={draft.job_middle_category_ids.length + majorOnlyIds.length}
          onClear={clearJobCategories}
          description={`興味のある職種のどれか1つが一致すれば、条件に合います。大分類だけ選ぶと、その大分類の職種すべてで探します。${BLANK_NOTE}`}
        >
          <JobCategoryPicker
            key={jobCategoryResetKey}
            name="search-job-category"
            legend="職種"
            majors={majors}
            selectedIds={draft.job_middle_category_ids}
            disabledIds={[]}
            disabledNote=""
            onChange={(ids) => updateDraft("job_middle_category_ids", ids)}
            initialCheckedMajorIds={checkedMajorIds}
            onCheckedMajorsChange={setCheckedMajorIds}
          />
        </SearchConditionDialog>

        {/* 学年・卒業年度・活動状況：それぞれ、どれかに当てはまれば合う */}
        <SearchConditionDialog
          label="学年・卒業年度・活動状況"
          count={profileCount}
          onClear={() => setDraft({ ...draft, grades: [], graduation_years: [], activity_statuses: [] })}
          description={`それぞれ、選んだもののどれかに当てはまれば条件に合います。${BLANK_NOTE}`}
        >
          <FieldGroup>
            <EnumCheckboxGroup
              name="search-grade"
              legend="学年"
              choices={options.enums.grade}
              selected={draft.grades}
              onChange={(values) => updateDraft("grades", values)}
            />
            <MasterCheckboxGroup
              name="search-graduation-year"
              legend="卒業年度"
              rows={graduationYears.map((year) => ({ id: year, name: `${year}年卒` }))}
              selectedIds={draft.graduation_years}
              onChange={(ids) => updateDraft("graduation_years", ids)}
              columnsClassName="grid-cols-2 sm:grid-cols-4"
            />
            <EnumCheckboxGroup
              name="search-activity-status"
              legend="活動状況"
              choices={options.enums.activity_status}
              selected={draft.activity_statuses}
              onChange={(values) => updateDraft("activity_statuses", values)}
            />
          </FieldGroup>
        </SearchConditionDialog>

        {/* フリーワード。自己PRの3つと、プログラミング歴の「その他」の名前が対象（名前と大学名は対象にしない。16-3 ㉒） */}
        <Input
          aria-label="フリーワード"
          value={draft.q}
          placeholder="フリーワード（自己PR、プログラミング歴の「その他」）"
          onChange={(event) => updateDraft("q", event.target.value)}
          className="min-w-48 flex-1"
        />

        <Button type="submit">検索する</Button>
      </form>
      {/* ポップアップは閉じているかもしれないので、条件欄の下にも出す */}
      {startMonthErrors && <p className="text-sm text-destructive">{startMonthErrors.join("")}</p>}
    </div>
  );
}

type SkillLevelChoicesProps = {
  // ⑦ の enums.skill_level（"v1"〜"v4" と、その意味）
  levels: EnumOption[];
  value: string | null;
  onChange: (value: string | null) => void;
};

// 技術のレベル：1つだけ選ぶ。ボタンは「v2以上」のように短くし、各レベルの意味は下に並べる
function SkillLevelChoices({ levels, value, onChange }: SkillLevelChoicesProps) {
  return (
    <div className="space-y-2">
      <ChoiceButtons
        legend="技術のレベル（選んだ技術すべてが、このレベル以上）"
        choices={levels.map((level) => ({ value: level.value, label: `${level.value}以上` }))}
        value={value}
        onChange={onChange}
      />
      <FieldDescription>
        {levels.map((level) => (
          <span key={level.value} className="block">
            {level.label}
          </span>
        ))}
        技術を選ばずにレベルだけ選んでも、条件として使いません
      </FieldDescription>
    </div>
  );
}

type EnumCheckboxGroupProps = {
  // チェックボックスの id を作るのに使う
  name: string;
  legend: string;
  // ⑦ の enums の選択肢（値と表示名）
  choices: EnumOption[];
  selected: string[];
  onChange: (values: string[]) => void;
};

// 選択肢（学年、活動状況）をチェックボックスで並べ、複数選ぶ。
// マスタの部品（MasterCheckboxGroup）は番号で選ぶので、名前で選ぶこちらを別に置く
function EnumCheckboxGroup({ name, legend, choices, selected, onChange }: EnumCheckboxGroupProps) {
  function toggle(value: string, checked: boolean) {
    onChange(checked ? [...selected, value] : selected.filter((item) => item !== value));
  }

  return (
    <FieldSet>
      <FieldLegend variant="label">{legend}</FieldLegend>
      <div className="grid gap-2 sm:grid-cols-2">
        {choices.map((choice) => {
          const id = `${name}-${choice.value}`;
          return (
            <Field key={choice.value} orientation="horizontal">
              <Checkbox
                id={id}
                checked={selected.includes(choice.value)}
                onCheckedChange={(checked) => toggle(choice.value, checked)}
              />
              <FieldLabel htmlFor={id} className="font-normal">
                {choice.label}
              </FieldLabel>
            </Field>
          );
        })}
      </div>
    </FieldSet>
  );
}

// ── 並び順のタブ ──

type SortTabsProps = {
  state: StudentSearchState;
  // 選んでいる募集の名前。選んでいなければ null
  selectedTitle: string | null;
  onChange: (sort: StudentSearchSort) => void;
};

// [「○○」におすすめ順] [最終活動が新しい順]。
// おすすめ順は、選んだ募集を元に並べるので、募集を選んでいないときは押せない（PR214。今は仮の全員0点）
function SortTabs({ state, selectedTitle, onChange }: SortTabsProps) {
  const canRecommend = state.jobPostingId !== null;
  const tabs: { sort: StudentSearchSort; label: string; disabled: boolean }[] = [
    {
      sort: "recommended",
      label: selectedTitle ? `「${selectedTitle}」におすすめ順` : "募集におすすめ順",
      disabled: !canRecommend,
    },
    { sort: "last_active", label: "最終活動が新しい順", disabled: false },
  ];

  return (
    <div className="flex flex-wrap items-center gap-2">
      <nav aria-label="並び順" className="flex flex-wrap gap-2">
        {tabs.map((tab) => {
          const selected = tab.sort === state.sort;
          return (
            <button
              key={tab.sort}
              type="button"
              disabled={tab.disabled}
              aria-pressed={selected}
              onClick={() => onChange(tab.sort)}
              className={buttonVariants({ variant: selected ? "secondary" : "ghost", size: "sm" })}
            >
              {tab.label}
            </button>
          );
        })}
      </nav>
      {!canRecommend && <span className="text-sm text-muted-foreground">おすすめ順は、募集を選ぶと使えます</span>}
    </div>
  );
}

// ── 結果 ──

type SearchResultsProps = {
  result: CompanyStudentSearchResult;
  options: Options;
  // 選んでいる募集。学生詳細を、その募集のタブを選んだ状態で開くために使う
  jobPostingId: string | null;
  hrefFor: (page: number) => string;
};

function SearchResults({ result, options, jobPostingId, hrefFor }: SearchResultsProps) {
  const { items, pagination } = result;
  // このページの先頭の行が、全体で何番目か（0から数える）
  const firstIndex = (pagination.page - 1) * pagination.per_page;

  return (
    <div className="space-y-4">
      {/* 人数は2つ出す（ページ設計.md の 6-5 C5） */}
      <p className="text-sm">
        条件に合う <span className="font-bold">{pagination.matched_count}</span>人／全 {pagination.total_count}人
      </p>

      {pagination.total_count === 0 ? (
        // 条件で減らさないので、0人になるのは「30日以内に活動した学生がいない」ときだけ
        <p className="text-sm text-muted-foreground">表示できる学生がいません</p>
      ) : items.length === 0 ? (
        // 範囲外のページ（URL を手で書き換えたときなど）
        <p className="text-sm text-muted-foreground">このページに学生はいません</p>
      ) : (
        <ul className="space-y-3">
          {items.map((item, index) => (
            <Fragment key={item.id}>
              {/* 全体で matched_count 番目の行の前に区切りを出す（募集一覧と同じ決まり）。
                  1ページ目の途中、ページの境目、合致0人（先頭）のどれでも、この1つの決まりで正しい位置になる */}
              {firstIndex + index === pagination.matched_count && (
                <li className="flex items-center gap-3 py-2 text-sm text-muted-foreground">
                  <span className="h-px flex-1 bg-border" />
                  ここから条件に合いません
                  <span className="h-px flex-1 bg-border" />
                </li>
              )}
              <StudentRow
                student={item}
                options={options}
                jobPostingId={jobPostingId}
                tag={tagOf(item, jobPostingId, options)}
              />
            </Fragment>
          ))}
        </ul>
      )}

      <PageNav page={pagination.page} totalPages={pagination.total_pages} hrefFor={hrefFor} />
    </div>
  );
}

// ── 学生1人の行 ──

// 行の名前の横に出す札（PR219）。出さないなら null。
// タグは Rails が計算したものを日本語にするだけ（画面側では組み立てない。16-1-9）。
// 除外のあとなので、募集を選んだときに付くのは「未対応応募」だけ（PR220）
function tagOf(
  item: CompanyStudentSearchResult["items"][number],
  jobPostingId: string | null,
  options: Options,
): string | null {
  if (item.candidacy) return labelOf(options.enums.candidacy_tag, item.candidacy.tag) ?? item.candidacy.tag;
  // 募集を選んでいないとき：自社のどれかの募集とやりとりがあれば「やりとりあり」（ページ設計.md の 6-5 C5）
  if (jobPostingId === null && item.candidacy_count > 0) return "やりとりあり";
  return null;
}

type StudentRowProps = {
  student: CompanyStudentRow;
  options: Options;
  jobPostingId: string | null;
  // 名前の横に出す札。null なら出さない
  tag: string | null;
};

// 名前（と札）、学年・卒業年度・活動状況、興味のある職種、プログラミング歴、稼働条件と、「詳細を見る」
function StudentRow({ student, options, jobPostingId, tag }: StudentRowProps) {
  // 学生詳細。募集を選んでいれば、その募集のタブを選んだ状態で開く
  const detailHref = `/company/students/${student.id}${
    jobPostingId === null ? "" : `?job_posting_id=${encodeURIComponent(jobPostingId)}`
  }`;
  // 学年・卒業年度・活動状況。空欄の項目は飛ばす
  const profileParts = [
    labelOf(options.enums.grade, student.grade),
    student.graduation_year === null ? null : `${student.graduation_year}年卒`,
    labelOf(options.enums.activity_status, student.activity_status),
  ].filter((part) => part !== null);
  const jobCategoryNames = jobMiddleCategoryNames(
    options.masters.job_major_categories,
    student.interested_job_middle_category_ids,
  );
  // プログラミング歴。「Ruby（v3）」のように、技術の名前（なければ「その他」の名前）とレベル
  const skillNames = student.skills.map(
    (skill) => `${nameOf(options.masters.technologies, skill.technology_id) ?? skill.other_name ?? ""}（${skill.level}）`,
  );
  // 稼働条件。学生が入れているのは上限なので「まで」「以上続けられる」を付ける（学生詳細と同じ書き方）。空欄は飛ばす
  const workConditionParts = [
    student.work_days_per_week === null ? null : `週${student.work_days_per_week}日まで`,
    student.work_hours_per_day === null ? null : `1日${student.work_hours_per_day}時間まで`,
    student.duration_months === null ? null : `${student.duration_months}ヶ月以上`,
  ].filter((part) => part !== null);

  return (
    <li className="space-y-3 rounded-lg border p-4">
      <div className="flex flex-wrap items-center gap-2">
        <ProfileIcon src={student.icon_url} name={student.name} size="sm" />
        <Link href={detailHref} className="font-bold hover:underline">
          {student.name}
        </Link>
        {/* 見た目は、候補者一覧の行のタグとそろえる（同じ部品） */}
        {tag && <StatusBadge size="sm">{tag}</StatusBadge>}
      </div>

      <div className="space-y-1 text-sm">
        {profileParts.length > 0 && <p className="text-muted-foreground">{profileParts.join(" ・ ")}</p>}
        {jobCategoryNames.length > 0 && <p>興味のある職種：{jobCategoryNames.join("・")}</p>}
        {skillNames.length > 0 && <p>プログラミング歴：{skillNames.join("・")}</p>}
        {workConditionParts.length > 0 && <p>稼働条件：{workConditionParts.join("・")}</p>}
      </div>

      <Link href={detailHref} className={buttonVariants({ variant: "outline", size: "sm" })}>
        詳細を見る
      </Link>
    </li>
  );
}
