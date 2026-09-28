"use client";

// 募集一覧（S2。学生のホーム）の中身。詳しくは design/designs/ページ設計.md の 6-6 S2、API設計.md の 16-3 ⑱・16-1-11。
//
// 条件・並び順・ページは、すべて URL の ? の後ろに持つ（URL が正。16-1-13）。
// 画面の URL の ? の後ろを、そのまま ⑱ GET /api/student/job_postings に渡す（形が同じなので変換しない）。
// - 条件欄は [勤務地][職種][技術][工程][稼働条件](フリーワード)[検索する] の横並び。各ボタンはポップアップを開く（PR201）
// - 条件欄を触っても、画面の中の下書きが変わるだけ。「検索する」を押したときに URL に書き込む（PR192）
// - 並び順は、選んだらすぐ URL に書き込む（PR196）
// - URL が変わると SWR が Rails に取りに行く。ブラウザの「戻る」で、条件欄も結果も前の URL の内容に戻る
//
// 結果は条件で減らさず、合致の群を先に、合致外の群をあとに並べて返ってくる（Rails が並べる）。
// 画面は、合致外に変わるところに「ここから条件に合いません」の区切りを入れるだけ（処理設計_類似度.md の 7-3）。
// 自分が応募した募集・マッチした募集は、Rails が結果から除いて返す（PR253）。
// 並び順と条件は切り離す。おすすめ順は並び順だけを変え、条件は画面で選んだものだけを使う。
// 自分の稼働条件は、稼働条件のポップアップの「自分の稼働条件で選ぶ」を押したときだけ下書きに入る（PR302）。
// 業界・事業形態の条件は、順13 の最後（PR299）で足す

import { Fragment, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { JobCategoryPicker } from "@/components/job-category-picker";
import { MasterCheckboxGroup } from "@/components/master-checkbox-group";
import { PageNav } from "@/components/page-nav";
import { PageTitle } from "@/components/page-title";
import { SearchConditionDialog } from "@/components/search-condition-dialog";
import {
  countWorkConditions,
  EMPTY_WORK_CONDITIONS,
  fromWorkConditionsDraft,
  SearchWorkConditions,
  toWorkConditionsDraft,
  type WorkConditionsDraft,
  workConditionsDraftFromProfile,
} from "@/components/search-work-conditions";
import { StudentJobPostingRow } from "@/components/student-job-posting-row";
import { TechnologyPicker } from "@/components/technology-picker";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { NativeSelect, NativeSelectOption } from "@/components/ui/native-select";
import { useApi } from "@/lib/api";
import { isHalfSelectedMonth } from "@/lib/form-values";
import { type Options, useOptions } from "@/lib/options";
import {
  buildSearchQuery,
  conditionsFromQuery,
  type JobPostingSearchResult,
  type SearchConditions,
  type SearchSort,
  sortFromQuery,
} from "@/lib/student-job-postings";
import type { StudentProfile } from "@/lib/student-profile";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

const PAGE_PATH = "/student/job_postings";

// 並び順の選択肢。Rails の 16-3 ⑱ の sort の値と対応する
const SORT_CHOICES: { value: SearchSort; label: string }[] = [
  { value: "recommended", label: "おすすめ順" },
  { value: "newest", label: "新着順" },
];

// ? の後ろから、画面の URL を作る
function pageUrl(query: string): string {
  return query === "" ? PAGE_PATH : `${PAGE_PATH}?${query}`;
}

export function StudentJobPostingSearch() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const query = searchParams.toString();
  const { options, failed: optionsFailed } = useOptions();
  // 401 は共通の枠（member-only.tsx）がログイン画面へ移す。
  // keepPreviousData：次の結果が届くまで前の結果を出したままにする（ページ送りで画面がちらつかないように）
  const { data, error } = useApi<JobPostingSearchResult>(`/api/student/job_postings${query === "" ? "" : `?${query}`}`, {
    keepPreviousData: true,
  });
  // 自分のプロフィール（⑮。「自分の稼働条件で選ぶ」に使う）。届くまでは、そのボタンを押せない
  const { data: profile } = useApi<StudentProfile>("/api/student/profile");

  // 今の URL の条件と並び順（下書きではなく、実際に検索している内容）
  const currentConditions = conditionsFromQuery(searchParams);
  const sort = sortFromQuery(searchParams);

  // 「検索する」：下書きを URL に書き込む。1ページ目に戻る
  function search(conditions: SearchConditions) {
    router.push(pageUrl(buildSearchQuery(conditions, sort, 1)));
  }

  // 並び順：今の URL の条件のまま、並び順だけ変える。1ページ目に戻る（PR196）
  function changeSort(nextSort: SearchSort) {
    router.push(pageUrl(buildSearchQuery(currentConditions, nextSort, 1)));
  }

  if (optionsFailed) {
    return <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  }

  if (!options) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  return (
    <div className="space-y-6">
      <PageTitle>募集一覧</PageTitle>

      {/* key に URL を渡す：URL が変わったら条件欄を作り直し、下書きを URL の内容に戻す（「戻る」のため） */}
      <SearchForm key={query} initial={currentConditions} options={options} profile={profile} onSearch={search} />

      {!data && error && error.status !== 401 ? (
        <p className="text-sm text-destructive">{error.message}</p>
      ) : !data ? (
        <p className="text-sm text-muted-foreground">読み込み中…</p>
      ) : (
        <SearchResults
          result={data}
          options={options}
          sort={sort}
          onSortChange={changeSort}
          hrefFor={(page) => pageUrl(buildSearchQuery(currentConditions, sort, page))}
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
  initial: SearchConditions;
  options: Options;
  // 自分のプロフィール。まだ届いていなければ undefined
  profile: StudentProfile | undefined;
  onSearch: (conditions: SearchConditions) => void;
};

function SearchForm({ initial, options, profile, onSearch }: SearchFormProps) {
  const majors = options.masters.job_major_categories;
  // 画面上で保持する条件（下書き）。「検索する」を押すまで Rails には送らない（PR192）
  const [draft, setDraft] = useState<SearchConditions>(initial);
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

  // 稼働条件の下書き。開始時期は、年と月の片方だけ選んだ状態も持てる形で持つ（PR200）
  const [workConditions, setWorkConditions] = useState<WorkConditionsDraft>(() => toWorkConditionsDraft(initial));
  // 開始時期の確認で見つかったエラー
  const [startMonthErrors, setStartMonthErrors] = useState<string[] | undefined>(undefined);
  // 職種の部品を作り直すための番号。「この条件をクリア」で1つ増やす。
  // 職種の部品は大分類のチェックを中で覚えているので、作り直さないと、クリアしてもチェックが残って見えるため
  const [jobCategoryResetKey, setJobCategoryResetKey] = useState(0);

  function updateDraft<K extends keyof SearchConditions>(key: K, value: SearchConditions[K]) {
    setDraft({ ...draft, [key]: value });
  }

  // 中分類を1つも選んでいない大分類（「大分類で探す」として送るもの）。
  // 中分類を選んだ大分類は、その中分類で探す（16-3 ⑱ の job_major_category_ids）
  const majorOnlyIds = checkedMajorIds.filter((majorId) => {
    const major = majors.find((row) => row.id === majorId);
    return !major?.job_middle_categories.some((middle) => draft.job_middle_category_ids.includes(middle.id));
  });

  function clearJobCategories() {
    setDraft({ ...draft, job_middle_category_ids: [] });
    setCheckedMajorIds([]);
    setJobCategoryResetKey(jobCategoryResetKey + 1);
  }

  // 「自分の稼働条件で選ぶ」（PR302）：稼働条件のポップアップの中身を、プロフィールの入力済みの値に置き換える。
  // 出社できる都道府県も稼働条件の一部なので、勤務地のポップアップも一緒に置き換える（PR304）。
  // 下書きが変わるだけで、「検索する」を押すまで結果は変わらない
  function fillFromProfile() {
    if (!profile) return;
    setWorkConditions(workConditionsDraftFromProfile(profile, workConditions));
    setDraft({ ...draft, prefecture_ids: profile.commutable_prefecture_ids });
    setStartMonthErrors(undefined);
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    // 開始時期は、年と月の両方を選ぶか、両方空欄にする（画面側だけの確認。マイページと同じ文言。権限_バリデーション.md の 17-3-6）
    if (isHalfSelectedMonth(workConditions.start_year, workConditions.start_month)) {
      setStartMonthErrors(["開始時期は年と月の両方を選んでください"]);
      return;
    }
    setStartMonthErrors(undefined);
    onSearch({ ...draft, job_major_category_ids: majorOnlyIds, ...fromWorkConditionsDraft(workConditions) });
  }

  // [勤務地][職種][技術][稼働条件](フリーワード)[検索する] を横に並べる。狭い画面では折り返す。
  // 各ボタンを押すとポップアップが開き、中で選んだものはその場で下書きに入る（PR201）
  return (
    <div className="space-y-2">
      <form onSubmit={submit} className="flex flex-wrap items-center gap-2">
        {/* ② 勤務地：47都道府県をそのまま並べる */}
        <SearchConditionDialog
          label="勤務地"
          count={draft.prefecture_ids.length}
          onClear={() => updateDraft("prefecture_ids", [])}
          description="フルリモートの募集は、勤務地に関係なく条件に合います"
          contentClassName="sm:max-w-3xl"
        >
          <MasterCheckboxGroup
            name="search-prefecture"
            legend="勤務地"
            hideLegend
            rows={options.masters.prefectures}
            selectedIds={draft.prefecture_ids}
            onChange={(ids) => updateDraft("prefecture_ids", ids)}
            columnsClassName="grid-cols-2 sm:grid-cols-4 md:grid-cols-6"
          />
        </SearchConditionDialog>

        {/* ④ 職種：大分類 → 中分類。大分類だけ選ぶと、その大分類の職種すべてで探す。
            ポップアップを閉じると中の部品は消えるので、開き直すときに、覚えている大分類のチェックを渡して元に戻す */}
        <SearchConditionDialog
          label="職種"
          count={draft.job_middle_category_ids.length + majorOnlyIds.length}
          onClear={clearJobCategories}
          description="大分類だけ選ぶと、その大分類の職種すべてで探します"
        >
          <JobCategoryPicker
            key={jobCategoryResetKey}
            name="search-job-category"
            legend="職種"
            majors={majors}
            selectedIds={draft.job_middle_category_ids}
            onChange={(ids) => updateDraft("job_middle_category_ids", ids)}
            initialCheckedMajorIds={checkedMajorIds}
            onCheckedMajorsChange={setCheckedMajorIds}
          />
        </SearchConditionDialog>

        {/* 使用技術：フリーワードでは拾えない表記の揺れ（「JS」と「JavaScript」など）を、選んで探せるようにする（PR199）。
            募集詳細編集と同じ部品 */}
        <SearchConditionDialog
          label="技術"
          count={draft.technology_ids.length}
          onClear={() => updateDraft("technology_ids", [])}
          description="選んだ技術のどれか1つを使う募集が、条件に合います"
        >
          <TechnologyPicker
            name="search-technology"
            legend="使用言語・フレームワーク・技術"
            options={options}
            selectedIds={draft.technology_ids}
            onChange={(ids) => updateDraft("technology_ids", ids)}
          />
        </SearchConditionDialog>

        {/* ④ 工程：関わりたい段階で探す（PR251）。13個を上流 → 下流の表示順で並べる。技術と同じ形 */}
        <SearchConditionDialog
          label="工程"
          count={draft.work_process_ids.length}
          onClear={() => updateDraft("work_process_ids", [])}
          description="選んだ工程のどれか1つに関われる募集が、条件に合います"
        >
          <MasterCheckboxGroup
            name="search-work-process"
            legend="工程"
            hideLegend
            rows={options.masters.work_processes}
            selectedIds={draft.work_process_ids}
            onChange={(ids) => updateDraft("work_process_ids", ids)}
          />
        </SearchConditionDialog>

        {/* ③ 稼働条件：週の日数、1日の時間、継続期間、開始時期、勤務形態、土日OK（PR200） */}
        <SearchConditionDialog
          label="稼働条件"
          count={countWorkConditions(workConditions)}
          onClear={() => {
            setWorkConditions(EMPTY_WORK_CONDITIONS);
            setStartMonthErrors(undefined);
          }}
          description="無理なく続けられる範囲で選んでください。募集の条件が未入力の項目は、条件に合わない側に入ります"
        >
          <div className="space-y-6">
            {/* 勤務地（出社できる都道府県）も一緒に選ぶ（PR304） */}
            <Button
              type="button"
              variant="outline"
              size="sm"
              disabled={!profile}
              onClick={fillFromProfile}
            >
              自分の稼働条件で選ぶ
            </Button>
            <SearchWorkConditions
              options={options}
              draft={workConditions}
              onChange={setWorkConditions}
              startMonthErrors={startMonthErrors}
            />
          </div>
        </SearchConditionDialog>

        {/* ① フリーワード。画面に出る文章と、会社名・職種・技術の名前が対象（PR198） */}
        <Input
          aria-label="フリーワード"
          value={draft.q}
          placeholder="フリーワード（例：Ruby、バックエンド、会社名）"
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

// ── 結果 ──

type SearchResultsProps = {
  result: JobPostingSearchResult;
  options: Options;
  sort: SearchSort;
  onSortChange: (sort: SearchSort) => void;
  hrefFor: (page: number) => string;
};

function SearchResults({ result, options, sort, onSortChange, hrefFor }: SearchResultsProps) {
  const { items, pagination } = result;
  // このページの先頭の行が、全体で何番目か（0から数える）
  const firstIndex = (pagination.page - 1) * pagination.per_page;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-4">
        {/* 件数は2つ出す（ページ設計.md の 6-6 S2） */}
        <p className="text-sm">
          条件に合う <span className="font-bold">{pagination.matched_count}</span>件／全 {pagination.total_count}件
        </p>
        <div className="flex items-center gap-2">
          <label htmlFor="search-sort" className="text-sm">
            並び順
          </label>
          <NativeSelect
            id="search-sort"
            value={sort}
            onChange={(event) => onSortChange(event.target.value as SearchSort)}
          >
            {SORT_CHOICES.map((choice) => (
              <NativeSelectOption key={choice.value} value={choice.value}>
                {choice.label}
              </NativeSelectOption>
            ))}
          </NativeSelect>
        </div>
      </div>

      {pagination.total_count === 0 ? (
        // 応募した募集・マッチした募集は除かれるので（PR253）、「掲載中の募集がない」とは限らない
        <p className="text-sm text-muted-foreground">表示できる募集はありません</p>
      ) : items.length === 0 ? (
        // 範囲外のページ（URL を手で書き換えたときなど）
        <p className="text-sm text-muted-foreground">このページに募集はありません</p>
      ) : (
        <ul className="space-y-3">
          {items.map((item, index) => (
            <Fragment key={item.id}>
              {/* 全体で matched_count 番目の行の前に区切りを出す。
                  1ページ目の途中、ページの境目、合致0件（先頭）のどれでも、この1つの決まりで正しい位置になる */}
              {firstIndex + index === pagination.matched_count && (
                <li className="flex items-center gap-3 py-2 text-sm text-muted-foreground">
                  <span className="h-px flex-1 bg-border" />
                  ここから条件に合いません
                  <span className="h-px flex-1 bg-border" />
                </li>
              )}
              <StudentJobPostingRow jobPosting={item} options={options} />
            </Fragment>
          ))}
        </ul>
      )}

      <PageNav page={pagination.page} totalPages={pagination.total_pages} hrefFor={hrefFor} />
    </div>
  );
}
