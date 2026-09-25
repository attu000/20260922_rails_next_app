// 募集の型。Rails の app/views/api/company/job_postings/ の JSON と同じ形（design/designs/API設計.md の 16-3 ⑪⑫）

// ⑪ 自社の募集の一覧の1行（index.json.jbuilder）
export type JobPostingRow = {
  id: number;
  title: string;
  // "unpublished" など。表示名は ⑦ の enums.job_posting_status から引く
  status: string;
  // 最初に掲載した日時。一度も掲載していなければ null
  published_at: string | null;
  updated_at: string;
};

// ⑫ 自社の募集1件（show.json.jbuilder）。⑬ 新規作成・⑭ 保存の返事も同じ形。空欄は null
export type JobPosting = {
  id: number;
  status: string;
  published_at: string | null;
  title: string;
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
  // 職種は「主な／関連する」で配列を分けて持つ（フォームの入力欄とそのまま対応させるため）
  main_job_middle_category_ids: number[];
  related_job_middle_category_ids: number[];
  technology_ids: number[];
  updated_at: string;
};
