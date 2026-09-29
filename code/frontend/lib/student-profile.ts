// 学生プロフィールの型。Rails の app/views/api/student/profiles/show.json.jbuilder と同じ形
// （design/designs/API設計.md の 16-3 ⑮⑯）。空欄は null。
// 外部リンク・資格・就活希望エリアは【仕上げ】の順17 で足した（興味のある業界は順10 で前倒しした。PR254）

// 外部リンクの1行。URL は http:// か https:// で始まる（Rails が確かめる。PR338）
export type StudentLink = {
  url: string;
  // 「GitHub」などの表示名。空欄は null
  title: string | null;
};

// プログラミング歴の1行。技術をマスタから選んだか、「その他」に名前を書いたかの、どちらか一方
export type StudentSkill = {
  // 「その他」の行なら null
  technology_id: number | null;
  other_name: string | null;
  // 年数。Rails が数値で返す（0.5刻み）
  years: number | null;
  // "v1"〜"v4"。表示名は ⑦ の enums.skill_level から引く
  level: string;
};

// ⑮ 自分のプロフィール。⑯ 保存の返事も同じ形
export type StudentProfile = {
  name: string;
  university_id: number | null;
  // 一覧にない大学（海外の大学など）の名前。university_id と両方同時には入らない
  university_other_name: string | null;
  faculty_id: number | null;
  department_id: number | null;
  // "undergrad_3" など。表示名は ⑦ の enums.grade
  grade: string | null;
  graduation_year: number | null;
  // 在住の都道府県
  prefecture_id: number | null;
  // "skill_up" など。表示名は ⑦ の enums.activity_status
  activity_status: string | null;
  self_pr_strength: string | null;
  self_pr_weakness: string | null;
  self_pr_future: string | null;
  work_days_per_week: number | null;
  work_hours_per_day: number | null;
  duration_months: number | null;
  // 月の1日の日付（"2026-11-01"）
  available_from: string | null;
  can_full_remote: boolean;
  can_partial_remote: boolean;
  can_onsite: boolean;
  work_note: string | null;
  // 働き方の好み（性格）の5軸。−2〜2（負＝左、正＝右、0＝真ん中）。空欄にはならない
  personality_pace: number;
  personality_novelty: number;
  personality_collaboration: number;
  personality_decision: number;
  personality_atmosphere: number;
  interested_job_middle_category_ids: number[];
  interested_industry_ids: number[];
  commutable_prefecture_ids: number[];
  // 就活希望エリア（都道府県の番号）
  job_hunting_prefecture_ids: number[];
  skills: StudentSkill[];
  links: StudentLink[];
  // 資格名の一覧（入力した順）
  certifications: string[];
  icon_url: string | null;
};
