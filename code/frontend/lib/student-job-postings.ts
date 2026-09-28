// 学生から見た募集・企業の型。Rails の app/views/api/student/ の JSON と同じ形
// （design/designs/API設計.md の 16-3 ⑱⑲⑳、形B）。空欄は null。
// 企業から見た募集（lib/job-postings.ts）とは返す項目が違うので、別のファイルにしている

import { idsFromQuery, monthDateFromQuery, numberFromQuery, type QueryReader } from "@/lib/search-query";

// 募集の会社（行と詳細で共通）
export type StudentJobPostingCompany = {
  id: number;
  name: string;
  icon_url: string | null;
};

// 学生向けの募集の行（形B）。⑱ 募集検索と ⑳ 企業詳細の募集一覧
export type StudentJobPostingRow = {
  id: number;
  title: string;
  // 掲載中なら true。false なら「募集終了」と出す（非公開か終了かは学生に見せない）
  is_open: boolean;
  company: StudentJobPostingCompany;
  // その募集の業界・事業形態。会社情報の値では補わない（空なら空の配列）
  industry_ids: number[];
  business_type_ids: number[];
  main_job_middle_category_ids: number[];
  related_job_middle_category_ids: number[];
  main_work_process_ids: number[];
  involved_work_process_ids: number[];
  prefecture_id: number | null;
  // "partial_remote" など。表示名は ⑦ の enums.work_style
  work_style: string | null;
  hourly_wage: number | null;
  min_work_days_per_week: number | null;
  min_work_hours_per_day: number | null;
  min_duration_months: number | null;
  published_at: string;
};

// ⑱ 募集検索の返事。行は形B に matched（指定した条件を全部満たすか。Rails が判定する）を足したもの。
// 並び順は、matched が true の行がすべて先（16-1-11）
export type JobPostingSearchResult = {
  items: (StudentJobPostingRow & { matched: boolean })[];
  pagination: {
    page: number;
    per_page: number;
    total_count: number;
    // 条件に合う件数
    matched_count: number;
    total_pages: number;
  };
};

// ── 募集一覧（学生のホーム）の検索の条件と、URL の ? の後ろ ──
// 条件・並び順・ページは URL に持つ（API設計.md の 16-1-13）。
// 画面の URL と Rails に渡す ? の後ろは同じ形にする（名前も同じ。配列は Rails の受け取り方に合わせて "prefecture_ids[]"）

// 画面で持つ検索の条件（「検索する」を押すまでの下書き。PR192）
export type SearchConditions = {
  q: string;
  prefecture_ids: number[];
  // 業界・事業形態（順13。PR299）。選んだもののどれか1つを持つ募集が合う。募集の値だけで判定する
  industry_ids: number[];
  business_type_ids: number[];
  // 中分類を1つも選んでいない大分類（大分類だけで探す）
  job_major_category_ids: number[];
  job_middle_category_ids: number[];
  // 使用技術。選んだ技術のどれか1つを使う募集が合う（PR199）
  technology_ids: number[];
  // 工程。選んだ工程のどれか1つを、メインか関われるに持つ募集が合う（PR251）
  work_process_ids: number[];
  // ③ 稼働条件（PR200）。学生が出せる上限（週◯日まで、1日◯時間まで、◯ヶ月以上続けられる）。null は指定なし
  work_days_per_week: number | null;
  work_hours_per_day: number | null;
  duration_months: number | null;
  // 働き始められる月（月の1日の日付 "2026-11-01"）。null は指定なし
  available_from: string | null;
  // 働ける勤務形態（"partial_remote" など）。募集の勤務形態がこの中にあれば合う
  work_styles: string[];
  // true なら、土日OK の募集だけが合う
  weekend_ok: boolean;
};

// 並び順。省略時はおすすめ順（16-3 ⑱）
export type SearchSort = "recommended" | "newest";

// URL の ? の後ろ → 条件（「戻る」や、リンクから開いたときに条件欄を埋める）
export function conditionsFromQuery(params: QueryReader): SearchConditions {
  return {
    q: params.get("q") ?? "",
    prefecture_ids: idsFromQuery(params, "prefecture_ids"),
    industry_ids: idsFromQuery(params, "industry_ids"),
    business_type_ids: idsFromQuery(params, "business_type_ids"),
    job_major_category_ids: idsFromQuery(params, "job_major_category_ids"),
    job_middle_category_ids: idsFromQuery(params, "job_middle_category_ids"),
    technology_ids: idsFromQuery(params, "technology_ids"),
    work_process_ids: idsFromQuery(params, "work_process_ids"),
    work_days_per_week: numberFromQuery(params, "work_days_per_week"),
    work_hours_per_day: numberFromQuery(params, "work_hours_per_day"),
    duration_months: numberFromQuery(params, "duration_months"),
    available_from: monthDateFromQuery(params, "available_from"),
    work_styles: params.getAll("work_styles[]"),
    weekend_ok: params.get("weekend_ok") === "true",
  };
}

// URL の ? の後ろ → 並び順。知らない値はおすすめ順（Rails と同じ扱い）
export function sortFromQuery(params: QueryReader): SearchSort {
  return params.get("sort") === "newest" ? "newest" : "recommended";
}

// 条件・並び順・ページ → URL の ? の後ろ（"q=ruby&prefecture_ids%5B%5D=13"。[] は符号化される）。
// 空の条件は書かない。既定の並び順（おすすめ順）と1ページ目は省く
export function buildSearchQuery(conditions: SearchConditions, sort: SearchSort, page: number): string {
  const params = new URLSearchParams();
  const q = conditions.q.trim();
  if (q !== "") params.set("q", q);
  conditions.prefecture_ids.forEach((id) => params.append("prefecture_ids[]", String(id)));
  conditions.industry_ids.forEach((id) => params.append("industry_ids[]", String(id)));
  conditions.business_type_ids.forEach((id) => params.append("business_type_ids[]", String(id)));
  conditions.job_major_category_ids.forEach((id) => params.append("job_major_category_ids[]", String(id)));
  conditions.job_middle_category_ids.forEach((id) => params.append("job_middle_category_ids[]", String(id)));
  conditions.technology_ids.forEach((id) => params.append("technology_ids[]", String(id)));
  conditions.work_process_ids.forEach((id) => params.append("work_process_ids[]", String(id)));
  if (conditions.work_days_per_week !== null) params.set("work_days_per_week", String(conditions.work_days_per_week));
  if (conditions.work_hours_per_day !== null) params.set("work_hours_per_day", String(conditions.work_hours_per_day));
  if (conditions.duration_months !== null) params.set("duration_months", String(conditions.duration_months));
  if (conditions.available_from !== null) params.set("available_from", conditions.available_from);
  conditions.work_styles.forEach((style) => params.append("work_styles[]", style));
  // 土日OK は true のときだけ書く
  if (conditions.weekend_ok) params.set("weekend_ok", "true");
  if (sort !== "recommended") params.set("sort", sort);
  if (page > 1) params.set("page", String(page));
  return params.toString();
}

// 学生から見た、募集とのやりとりの状態（形E。API設計.md の 16-3-2）。Rails が計算する。
// ⑲ 募集詳細の一部で、㉛ 応募の返事でもある
export type MyCandidacyStatus = {
  // "none"（関係なし）／"applied"（応募済み）／"scouted"（スカウトあり）／"matched"（マッチ済み）。
  // 見送り・合格・不合格は学生に見せない。表示名は ⑦ の enums.my_status
  my_status: string;
  // やりとりの番号。関係がなければ null
  my_candidacy_id: number | null;
};

// ⑲ 募集詳細
export type StudentJobPostingDetail = MyCandidacyStatus & {
  id: number;
  title: string;
  // 掲載中なら true。false なら「募集終了」と出す（やりとりがあれば、非公開・終了の募集も開ける）
  is_open: boolean;
  company: StudentJobPostingCompany;
  // どんな会社か・事業内容。募集が空欄なら、Rails が企業プロフィールの値を入れて返す
  about: string | null;
  business_description: string | null;
  internship_details: string | null;
  growth: string | null;
  min_work_days_per_week: number | null;
  min_work_hours_per_day: number | null;
  min_duration_months: number | null;
  // 月の1日の日付（"2026-10-01"）。null は随時
  start_month: string | null;
  work_style: string | null;
  work_style_note: string | null;
  prefecture_id: number | null;
  work_location_note: string | null;
  weekend_ok: boolean;
  work_note: string | null;
  hourly_wage: number | null;
  requirements: string | null;
  preferred_requirements: string | null;
  technology_note: string | null;
  main_job_middle_category_ids: number[];
  related_job_middle_category_ids: number[];
  main_work_process_ids: number[];
  involved_work_process_ids: number[];
  technology_ids: number[];
  // その募集の業界・事業形態。どんな会社か・事業内容と違い、空でも会社情報の値で補わない
  industry_ids: number[];
  business_type_ids: number[];
  // カルチャーの5軸。−2〜2（負＝左、正＝右、0＝真ん中）
  culture_pace: number;
  culture_novelty: number;
  culture_collaboration: number;
  culture_decision: number;
  culture_atmosphere: number;
  published_at: string;
  // その企業とのスレッドがあるか（スカウトが届いたか、マッチしたらできる）。
  // true なら「この企業とのメッセージ」のボタンを出す（権限_バリデーション.md の 17-2-3。PR213）
  has_message_thread: boolean;
  // 自分の働き方の好みの5軸。−2〜2。カルチャーグラフに黒丸で重ねる（順10。PR258）
  my_personality_pace: number;
  my_personality_novelty: number;
  my_personality_collaboration: number;
  my_personality_decision: number;
  my_personality_atmosphere: number;
};

// ㉞ 募集管理と ㉟ スカウト管理の返事（同じ形）。行は形B に、やりとりの番号と自分の状態を足したもの。
// 自分の状態は、募集管理なら "applied" か "matched"、スカウト管理なら常に "scouted"。
// 並び順は、やりとりが始まった日の新しい順（Rails が並べる）
export type StudentCandidacyListResult = {
  items: (StudentJobPostingRow & { candidacy_id: number; my_status: string })[];
  pagination: {
    page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
};

// ⑳ 企業詳細。業界・事業形態は企業プロフィールの値
export type StudentCompany = {
  id: number;
  name: string;
  industry_ids: number[];
  business_type_ids: number[];
  // "size_10_49" など。表示名は ⑦ の enums.employee_size
  employee_size: string | null;
  business_description: string | null;
  about: string | null;
  icon_url: string | null;
  // その企業とのスレッドがあるか。true なら「この企業とのメッセージ」のボタンを出す（募集詳細と同じ判定。PR213）
  has_message_thread: boolean;
  // その企業の掲載中の募集（最初に掲載した日時の新しい順。ページ分けしない）
  job_postings: StudentJobPostingRow[];
};
