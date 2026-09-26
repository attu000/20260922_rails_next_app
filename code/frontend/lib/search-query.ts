// 検索の画面で、URL の ? の後ろから条件を読む小さな関数。
// 募集一覧（学生のホーム）と学生検索（企業）で使い回す。
// 形のおかしい値は捨てる（「指定なし」として扱う。Rails も同じ扱い。PR200）

// useSearchParams() の返り値と URLSearchParams の、どちらでも読めるようにする
export type QueryReader = Pick<URLSearchParams, "get" | "getAll">;

// 番号の配列を読む（"prefecture_ids[]" のように [] 付きの名前）。正の整数でないものは捨てる
export function idsFromQuery(params: QueryReader, name: string): number[] {
  return params
    .getAll(`${name}[]`)
    .map(Number)
    .filter((id) => Number.isInteger(id) && id > 0);
}

// 数を1つ読む。正の整数でなければ null（指定なし）
export function numberFromQuery(params: QueryReader, name: string): number | null {
  const value = Number(params.get(name));
  return Number.isInteger(value) && value > 0 ? value : null;
}

// 月の1日の日付を読む（"2026-11-01"）。その形でなければ null（指定なし）
export function monthDateFromQuery(params: QueryReader, name: string): string | null {
  const value = params.get(name);
  return value !== null && /^\d{4}-\d{2}-01$/.test(value) ? value : null;
}
