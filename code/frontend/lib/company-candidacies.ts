// 企業から見たやりとりの型。Rails の app/views/api/company/candidacies/ の JSON と同じ形（design/designs/API設計.md の 16-3 ㉑）。
// 空欄は null

// ㉑ 候補者一覧の1行（やりとり1件）
export type CompanyCandidacyRow = {
  id: number;
  job_posting: {
    id: number;
    title: string;
    // "published" など。表示名は ⑦ の enums.job_posting_status
    status: string;
  };
  student: {
    id: number;
    name: string;
    icon_url: string | null;
    // "undergrad_3" など。表示名は ⑦ の enums.grade
    grade: string | null;
    graduation_year: number | null;
    // "job_hunting" など。表示名は ⑦ の enums.activity_status
    activity_status: string;
  };
  // "application"（応募）／"scout"（スカウト）
  origin: string;
  // "unmatched" など
  status: string;
  // 企業から見たタグ（"pending_application" など）。Rails が計算する。表示名は ⑦ の enums.candidacy_tag
  tag: string;
  // マッチ以降（マッチ・合格・不合格）か。Rails が判定する。true の行に「メッセージ」のボタンを出す（PR224）
  after_match: boolean;
  // 未返信か（マッチ以降で、学生が最後に送り、企業がまだ返していない）。Rails が判定する。true の行に「未返信」の札を出す
  unreplied: boolean;
  // やりとりが始まった日時（応募日・スカウト日）
  created_at: string;
  matched_at: string | null;
};

// ㉑ 候補者一覧の返事。並び順は、やりとりが始まった日の新しい順（Rails が並べる）
export type CompanyCandidacyListResult = {
  items: CompanyCandidacyRow[];
  pagination: {
    page: number;
    per_page: number;
    total_count: number;
    total_pages: number;
  };
};
