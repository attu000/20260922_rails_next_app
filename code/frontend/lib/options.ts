// ⑦ GET /api/options（選択肢とマスタ）を取る関数と、その型。
// 画面側は選択肢の表を自分で持たず、Rails が返したものだけを使う。一度取ったら使い回す（design/designs/API設計.md の 16-1-9）。
// 中身は機能を作るたびに足していく。型も、Rails の app/views/api/options/show.json.jbuilder に合わせて足す

import { useApi } from "@/lib/api";

// 選択肢（enum）：名前と日本語の表示名。例：{ value: "size_1_9", label: "1〜9人" }
export type EnumOption = { value: string; label: string };

// マスタの1行。例：{ id: 1, name: "EC・小売" }
export type MasterRow = { id: number; name: string };

// 職種の中分類。例：{ id: 1, code: "1-1", name: "フロントエンド", description: "…" }
export type JobMiddleCategory = { id: number; code: string; name: string; description: string };

// 職種の大分類。中に中分類を持つ
export type JobMajorCategory = {
  id: number;
  code: string;
  name: string;
  description: string;
  job_middle_categories: JobMiddleCategory[];
};

// 技術。category は区分の名前（"language" など。表示名は enums.technology_category）
export type TechnologyRow = { id: number; name: string; category: string };

// 学部。中に学科を持つ（学科は学部の中での表示順）
export type Faculty = { id: number; name: string; departments: MasterRow[] };

export type Options = {
  enums: {
    employee_size: EnumOption[];
    job_posting_status: EnumOption[];
    work_style: EnumOption[];
    technology_category: EnumOption[];
    // 学年・活動状況・プログラミング歴のレベル（順3）
    grade: EnumOption[];
    activity_status: EnumOption[];
    skill_level: EnumOption[];
  };
  // 稼働条件の数値の選択肢（その他決め事.md の 5-6）
  work_conditions: {
    work_days_per_week: number[];
    work_hours_per_day: number[];
    duration_months: number[];
  };
  masters: {
    job_major_categories: JobMajorCategory[];
    technologies: TechnologyRow[];
    industries: MasterRow[];
    business_types: MasterRow[];
    prefectures: MasterRow[];
    // 大学（学校コードの順）と学部（順3）
    universities: MasterRow[];
    faculties: Faculty[];
  };
};

// 画面から使う形。取れるまでは options が null。
// 選択肢はほとんど変わらないので、ページを読み込み直すまで1回だけ取り、あとは覚えているものを使い回す
export function useOptions(): { options: Options | null; failed: boolean } {
  const { data, error } = useApi<Options>("/api/options", {
    // 画面に戻ってきても取り直さない
    revalidateOnFocus: false,
    // 覚えている内容があれば、それを使い続ける
    revalidateIfStale: false,
  });

  return { options: data ?? null, failed: error !== undefined };
}

// 選択肢の名前（"size_10_49"）を、日本語の表示名（"10〜49人"）に直す。見つからなければ null
export function labelOf(enumOptions: EnumOption[], value: string | null): string | null {
  return enumOptions.find((option) => option.value === value)?.label ?? null;
}
