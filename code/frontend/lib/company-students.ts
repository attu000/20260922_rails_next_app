// 企業から見た学生の型。Rails の app/views/api/company/students/ の JSON と同じ形（design/designs/API設計.md の 16-3 ㉒㉓・形C・形D）。
// 空欄は null。比較（comparison）と応募理由（candidacy.reasons）は順10 で足す

import { idsFromQuery, monthDateFromQuery, numberFromQuery, type QueryReader } from "@/lib/search-query";
import type { StudentProfile } from "@/lib/student-profile";

// 形D：募集1件と、その学生とのやりとり。㉓ 学生詳細の job_postings の要素で、㉔ スカウト・㉖ マッチの返事でもある
export type CompanyJobPostingState = {
  id: number;
  title: string;
  // "published" など。表示名は ⑦ の enums.job_posting_status
  status: string;
  // その学生とのやりとり。なければ null
  candidacy: {
    id: number;
    // "application"（応募）／"scout"（スカウト）
    origin: string;
    // "unmatched" など
    status: string;
    // 企業から見たタグ（"pending_application" など）。Rails が計算する。表示名は ⑦ の enums.candidacy_tag
    tag: string;
    matched_at: string | null;
  } | null;
  // 今押せるボタンの名前（"match" など）。判定は Rails が行い、画面はここにあるボタンだけを出す（16-1-9）。
  // 今は "scout" と "match"。"decline"・"undo_decline"・"pass"・"fail" は順11 で Rails が返すようになる
  available_actions: string[];
};

// ㉓ 学生詳細
export type CompanyStudentDetail = {
  // マイページ（⑮）と同じ項目
  student: StudentProfile;
  // この学生とのスレッドがあるか（スカウトを送ったか、応募がマッチしたらできる）。
  // 「この学生とのメッセージ」のボタンに、行き先のメッセージ管理を作る順7 で使う（PR213）
  has_message_thread: boolean;
  // 自社の全募集（非公開・終了も含む。最終更新の新しい順）
  job_postings: CompanyJobPostingState[];
};

// 形C：企業向けの学生の行（㉒ 学生検索）。スカウトするかどうかの判断に使う情報だけ。
// 最終活動の目安（last_active_range）は【仕上げ】で足す
export type CompanyStudentRow = {
  id: number;
  name: string;
  icon_url: string | null;
  // "undergrad_3" など。表示名は ⑦ の enums.grade
  grade: string | null;
  graduation_year: number | null;
  // "job_hunting" など。表示名は ⑦ の enums.activity_status
  activity_status: string | null;
  interested_job_middle_category_ids: number[];
  // プログラミング歴。技術はマスタの番号か、「その他」の名前のどちらか。level は "v1"〜"v4"
  skills: { technology_id: number | null; other_name: string | null; level: string }[];
  // 学生が無理なく出せる上限（週◯日まで、1日◯時間まで、◯ヶ月以上続けられる）
  work_days_per_week: number | null;
  work_hours_per_day: number | null;
  duration_months: number | null;
};

// ㉒ 学生検索の返事。行は形C に、次の3つを足したもの。並び順は、matched が true の行がすべて先（16-1-11）。
// もうスカウトした・見送った・マッチした学生は、Rails が除いて返す（PR220）
export type CompanyStudentSearchResult = {
  items: (CompanyStudentRow & {
    // 指定した条件を全部満たすか（Rails が判定する）
    matched: boolean;
    // 募集を選んだときの、その募集とのやりとり。なければ null（募集を選ばないときは常に null）。
    // 除外のあとなので、あるのは未対応応募だけ。tag の表示名は ⑦ の enums.candidacy_tag（PR219）
    candidacy: { id: number; origin: string; status: string; tag: string } | null;
    // 自社の募集とのやりとりの件数。募集を選ばないときの「やりとりあり」の札に使う（PR219）
    candidacy_count: number;
  })[];
  pagination: {
    page: number;
    per_page: number;
    total_count: number;
    // 条件に合う人数
    matched_count: number;
    total_pages: number;
  };
};

// ── 学生検索の、選んだ募集・並び順・条件・ページと、URL の ? の後ろ ──
// すべて URL に持つ（URL が正。API設計.md の 16-1-13）。
// 画面の URL と Rails に渡す ? の後ろは同じ形にする（名前も同じ。配列は Rails の受け取り方に合わせて "grades[]"）

// 並び順。"recommended" は選んだ募集におすすめ順（募集が必要）、"last_active" は最終活動が新しい順
export type StudentSearchSort = "recommended" | "last_active";

// 画面で持つ検索の条件（「検索する」を押すまでの下書き。PR192）。null・空の配列・"" は指定なし。
// 合うかどうかの判定は Rails が行う（16-3 ㉒）
export type StudentSearchConditions = {
  // フリーワード（自己PRの3つ、プログラミング歴の「その他」の名前）
  q: string;
  // 稼働条件。企業が求める下限（週◯日以上など）。学生の上限がこの値以上なら合う
  work_days_per_week: number | null;
  work_hours_per_day: number | null;
  duration_months: number | null;
  // 開始時期（月の1日の日付 "2026-11-01"）。この月までに働き始められる学生が合う
  start_month: string | null;
  // 勤務形態（"onsite" など。1つだけ）
  work_style: string | null;
  // 勤務地（1つだけ）。勤務形態がフルリモートのときは、Rails が使わない
  prefecture_id: number | null;
  // 使用技術。選んだ技術をすべて持っている学生が合う。min_level（"v2" など）を選ぶと、そのレベル以上
  technology_ids: number[];
  min_level: string | null;
  // 職種。中分類を1つも選んでいない大分類は job_major_category_ids（大分類だけで探す）
  job_major_category_ids: number[];
  job_middle_category_ids: number[];
  // 学年・卒業年度・活動状況。どれかに当てはまれば合う
  grades: string[];
  graduation_years: number[];
  activity_statuses: string[];
};

// 何も指定していない条件
export const EMPTY_STUDENT_SEARCH_CONDITIONS: StudentSearchConditions = {
  q: "",
  work_days_per_week: null,
  work_hours_per_day: null,
  duration_months: null,
  start_month: null,
  work_style: null,
  prefecture_id: null,
  technology_ids: [],
  min_level: null,
  job_major_category_ids: [],
  job_middle_category_ids: [],
  grades: [],
  graduation_years: [],
  activity_statuses: [],
};

export type StudentSearchState = {
  // 選んだ自社の募集の番号（文字列のまま Rails に渡す。他社や存在しない番号なら Rails が 404）。選んでいなければ null
  jobPostingId: string | null;
  sort: StudentSearchSort;
  conditions: StudentSearchConditions;
  page: number;
};

// URL の ? の後ろ → 条件
function conditionsFromQuery(params: QueryReader): StudentSearchConditions {
  return {
    q: params.get("q") ?? "",
    work_days_per_week: numberFromQuery(params, "work_days_per_week"),
    work_hours_per_day: numberFromQuery(params, "work_hours_per_day"),
    duration_months: numberFromQuery(params, "duration_months"),
    start_month: monthDateFromQuery(params, "start_month"),
    work_style: params.get("work_style") || null,
    prefecture_id: numberFromQuery(params, "prefecture_id"),
    technology_ids: idsFromQuery(params, "technology_ids"),
    min_level: params.get("min_level") || null,
    job_major_category_ids: idsFromQuery(params, "job_major_category_ids"),
    job_middle_category_ids: idsFromQuery(params, "job_middle_category_ids"),
    grades: params.getAll("grades[]"),
    graduation_years: idsFromQuery(params, "graduation_years"),
    activity_statuses: params.getAll("activity_statuses[]"),
  };
}

// URL の ? の後ろ → 選んだ募集・並び順・条件・ページ。
// 並び順が URL になければ、募集を選んでいればおすすめ順、なければ最終活動の順（Rails の 16-3 ㉒ と同じ決まり）。
// 募集を選んでいないのにおすすめ順になっていたら、最終活動の順として扱う（Rails も 422 にするので、送らない）
export function studentSearchStateFromQuery(params: QueryReader): StudentSearchState {
  const jobPostingId = params.get("job_posting_id") || null;
  const sort: StudentSearchSort =
    jobPostingId === null || params.get("sort") === "last_active" ? "last_active" : "recommended";
  // 数でなければ1ページ目（Rails も同じ扱い）
  const requestedPage = Number(params.get("page"));
  const page = Number.isInteger(requestedPage) && requestedPage > 1 ? requestedPage : 1;
  return { jobPostingId, sort, conditions: conditionsFromQuery(params), page };
}

// 選んだ募集・並び順・条件・ページ → URL の ? の後ろ。空の条件は書かない。
// 並び順は、既定（募集を選んでいればおすすめ順、なければ最終活動の順）なら書かない。1ページ目も書かない
export function buildStudentSearchQuery(state: StudentSearchState): string {
  const { conditions } = state;
  const params = new URLSearchParams();
  if (state.jobPostingId !== null) params.set("job_posting_id", state.jobPostingId);

  const q = conditions.q.trim();
  if (q !== "") params.set("q", q);
  if (conditions.work_days_per_week !== null) params.set("work_days_per_week", String(conditions.work_days_per_week));
  if (conditions.work_hours_per_day !== null) params.set("work_hours_per_day", String(conditions.work_hours_per_day));
  if (conditions.duration_months !== null) params.set("duration_months", String(conditions.duration_months));
  if (conditions.start_month !== null) params.set("start_month", conditions.start_month);
  if (conditions.work_style !== null) params.set("work_style", conditions.work_style);
  if (conditions.prefecture_id !== null) params.set("prefecture_id", String(conditions.prefecture_id));
  conditions.technology_ids.forEach((id) => params.append("technology_ids[]", String(id)));
  if (conditions.min_level !== null) params.set("min_level", conditions.min_level);
  conditions.job_major_category_ids.forEach((id) => params.append("job_major_category_ids[]", String(id)));
  conditions.job_middle_category_ids.forEach((id) => params.append("job_middle_category_ids[]", String(id)));
  conditions.grades.forEach((grade) => params.append("grades[]", grade));
  conditions.graduation_years.forEach((year) => params.append("graduation_years[]", String(year)));
  conditions.activity_statuses.forEach((status) => params.append("activity_statuses[]", status));

  const defaultSort: StudentSearchSort = state.jobPostingId === null ? "last_active" : "recommended";
  if (state.sort !== defaultSort) params.set("sort", state.sort);
  if (state.page > 1) params.set("page", String(state.page));
  return params.toString();
}
