// フォームの値の変換。募集詳細編集（C3）とマイページ（S1）で使い回す。
// 入力欄は空欄を "" で、選択欄の数値も文字で持つ。Rails に送るときは、空欄を null、数値を数に直す

// null → ""（入力欄に入れる形）
export function toText(value: string | number | null): string {
  return value === null ? "" : String(value);
}

// "" → null、"3" → 3（送る形）
export function toNumberOrNull(value: string): number | null {
  return value.trim() === "" ? null : Number(value);
}

// "" → null（空欄の選択欄を送る形）
export function toStringOrNull(value: string): string | null {
  return value === "" ? null : value;
}

// 月の選択肢（"1"〜"12"）
export const MONTH_NUMBERS = Array.from({ length: 12 }, (_, index) => String(index + 1));

// 月の1日の日付を、年と月の2つの選択欄の値に分ける。"2026-10-01" → { year: "2026", month: "10" }、null → 両方 ""
export function splitMonthDate(date: string | null): { year: string; month: string } {
  if (!date) return { year: "", month: "" };
  const [year, month] = date.split("-");
  return { year, month: String(Number(month)) };
}

// 年と月の2つの選択欄の値を、月の1日の日付にまとめる。"2026" と "10" → "2026-10-01"。どちらかが空欄なら null
export function joinMonthDate(year: string, month: string): string | null {
  return year && month ? `${year}-${month.padStart(2, "0")}-01` : null;
}

// 年と月の片方だけが選ばれているか（「開始時期は年と月の両方を選んでください」を出す。権限_バリデーション.md の 17-3-6）
export function isHalfSelectedMonth(year: string, month: string): boolean {
  return (year === "") !== (month === "");
}

// 今年（日本時間で数える。API設計.md の 16-1-12）
export function currentYearInTokyo(): number {
  return Number(new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Tokyo", year: "numeric" }).format(new Date()));
}

// 年の選択肢：firstYear〜lastYear。保存済みの年がその範囲の外なら、その年も足す（Rails 側は範囲を制限しないため）。
// 募集・学生の開始年は今年−1〜今年＋2、卒業年度は今年〜今年＋10（ページ設計.md の 6-5 C3、6-6 S1）
export function yearChoices(firstYear: number, lastYear: number, savedYear: string): string[] {
  const years = Array.from({ length: lastYear - firstYear + 1 }, (_, index) => String(firstYear + index));
  if (savedYear !== "" && !years.includes(savedYear)) {
    years.push(savedYear);
    years.sort();
  }
  return years;
}
