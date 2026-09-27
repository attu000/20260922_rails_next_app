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

// 工程（上流 → 下流の表示順）
export type WorkProcess = { id: number; name: string };

// 学部。中に学科を持つ（学科は学部の中での表示順）
export type Faculty = { id: number; name: string; departments: MasterRow[] };

// 性格・カルチャーの5軸の1つ（その他決め事.md の 5-5）。
// 例：{ key: "pace", name: "進め方", left_label: "スピード", left_description: "まず動くものを作って見せ、…", right_label: "緻密さ", … }
export type CultureAxis = {
  key: string;
  name: string;
  left_label: string;
  left_description: string;
  right_label: string;
  right_description: string;
};

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
    // 応募理由（12個。画面に出す順）と、学生から見た、募集とのやりとりの状態（順5）
    candidacy_reason: EnumOption[];
    my_status: EnumOption[];
    // 企業から見た、やりとりの状態のタグ（未対応応募・スカウト済み など。順5）
    candidacy_tag: EnumOption[];
  };
  // 稼働条件の数値の選択肢（その他決め事.md の 5-6）
  work_conditions: {
    work_days_per_week: number[];
    work_hours_per_day: number[];
    duration_months: number[];
  };
  // 性格・カルチャーの5軸（順9）。学生の働き方の好みと、募集のカルチャーグラフで共通
  culture_axes: CultureAxis[];
  masters: {
    job_major_categories: JobMajorCategory[];
    // 工程（順9）
    work_processes: WorkProcess[];
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

// マスタの番号（13）を、名前（"東京都"）に直す。都道府県・技術・業界・事業形態などで使う。見つからなければ null
export function nameOf(rows: MasterRow[], id: number | null): string | null {
  return rows.find((row) => row.id === id)?.name ?? null;
}

// マスタの番号の一覧を、名前の一覧に直す。業界・事業形態・工程・技術などで使う。並びは渡した番号の順で、見つからない番号は飛ばす
export function namesOf(rows: MasterRow[], ids: number[]): string[] {
  return ids.flatMap((id) => nameOf(rows, id) ?? []);
}

// 職種の中分類の番号の一覧を、名前の一覧に直す（大分類の中を探す）。並びは渡した番号の順
export function jobMiddleCategoryNames(majors: JobMajorCategory[], ids: number[]): string[] {
  const middles = majors.flatMap((major) => major.job_middle_categories);
  return ids.flatMap((id) => middles.find((middle) => middle.id === id)?.name ?? []);
}
