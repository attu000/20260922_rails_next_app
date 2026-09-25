// 表示用に値を直す関数。日時の「9月25日」のような加工は画面側で行う（design/designs/API設計.md の 16-1-8）。
// Django のテンプレートの {{ value|date:"Y/m/d" }} にあたる

// 日付の書式。アプリは日本時間で動かすので、日本時間で数える（16-1-12）
const DATE_FORMAT = new Intl.DateTimeFormat("ja-JP", {
  timeZone: "Asia/Tokyo",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

// 日時（"2026-09-25T10:00:00.000+09:00"）を「2026/09/25」にする
export function formatDate(isoString: string): string {
  return DATE_FORMAT.format(new Date(isoString));
}
