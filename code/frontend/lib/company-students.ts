// 企業から見た学生の型。Rails の app/views/api/company/students/ の JSON と同じ形（design/designs/API設計.md の 16-3 ㉓・形D）。
// 空欄は null。has_message_thread は順6、比較（comparison）と応募理由（candidacy.reasons）は順10 で足す

import type { StudentProfile } from "@/lib/student-profile";

// 形D：募集1件と、その学生とのやりとり。㉓ 学生詳細の job_postings の要素で、㉖ マッチの返事でもある
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
  // 順5 は "match" だけ。"scout" は順6、"decline"・"undo_decline"・"pass"・"fail" は順11 で Rails が返すようになる
  available_actions: string[];
};

// ㉓ 学生詳細
export type CompanyStudentDetail = {
  // マイページ（⑮）と同じ項目
  student: StudentProfile;
  // 自社の全募集（非公開・終了も含む。最終更新の新しい順）
  job_postings: CompanyJobPostingState[];
};
