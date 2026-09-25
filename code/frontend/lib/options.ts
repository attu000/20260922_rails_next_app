// ⑦ GET /api/options（選択肢とマスタ）を取る関数と、その型。
// 画面側は選択肢の表を自分で持たず、Rails が返したものだけを使う。一度取ったら使い回す（design/designs/API設計.md の 16-1-9）。
// 中身は機能を作るたびに足していく。型も、Rails の app/views/api/options/show.json.jbuilder に合わせて足す

import { useEffect, useState } from "react";
import { apiFetch } from "@/lib/api";

// 選択肢（enum）：名前と日本語の表示名。例：{ value: "size_1_9", label: "1〜9人" }
export type EnumOption = { value: string; label: string };

// マスタの1行。例：{ id: 1, name: "EC・小売" }
export type MasterRow = { id: number; name: string };

export type Options = {
  enums: {
    employee_size: EnumOption[];
  };
  masters: {
    industries: MasterRow[];
    business_types: MasterRow[];
  };
};

// 取った結果を、ページを読み込み直すまでここに取っておく
let cachedOptions: Promise<Options> | null = null;

// 選択肢とマスタを取る。2回目からは、取っておいたものを返す（通信しない）
export function fetchOptions(): Promise<Options> {
  if (!cachedOptions) {
    cachedOptions = apiFetch<Options>("/api/options").catch((error: unknown) => {
      // 失敗は取っておかない。次に呼ばれたときに取り直す
      cachedOptions = null;
      throw error;
    });
  }
  return cachedOptions;
}

// 画面から使う形。取れるまでは options が null
export function useOptions(): { options: Options | null; failed: boolean } {
  const [options, setOptions] = useState<Options | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    // 画面を離れた後に返事が来たときは、何もしない
    let active = true;

    fetchOptions()
      .then((fetched) => {
        if (active) setOptions(fetched);
      })
      .catch(() => {
        if (active) setFailed(true);
      });

    return () => {
      active = false;
    };
  }, []);

  return { options, failed };
}

// 選択肢の名前（"size_10_49"）を、日本語の表示名（"10〜49人"）に直す。見つからなければ null
export function labelOf(enumOptions: EnumOption[], value: string | null): string | null {
  return enumOptions.find((option) => option.value === value)?.label ?? null;
}
