// 表示用に値を直す関数。日時の「9月25日」のような加工は画面側で行う（design/designs/API設計.md の 16-1-8）。
// Django のテンプレートの {{ value|date:"Y/m/d" }} にあたる

import { labelOf, nameOf, type Options } from "@/lib/options";

// 日付の書式。アプリは日本時間で動かすので、日本時間で数える（16-1-12）
const DATE_FORMAT = new Intl.DateTimeFormat("ja-JP", {
  timeZone: "Asia/Tokyo",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

// 日時の書式（時刻まで）。日本時間で数える
const DATE_TIME_FORMAT = new Intl.DateTimeFormat("ja-JP", {
  timeZone: "Asia/Tokyo",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
});

// 「9月20日」「2025年9月20日」と、年だけ（今年かを比べる）の書式。日本時間で数える
const MONTH_DAY_FORMAT = new Intl.DateTimeFormat("ja-JP", { timeZone: "Asia/Tokyo", month: "long", day: "numeric" });
const YEAR_MONTH_DAY_FORMAT = new Intl.DateTimeFormat("ja-JP", {
  timeZone: "Asia/Tokyo",
  year: "numeric",
  month: "long",
  day: "numeric",
});
const YEAR_FORMAT = new Intl.DateTimeFormat("ja-JP", { timeZone: "Asia/Tokyo", year: "numeric" });

// 日時（"2026-09-25T10:00:00.000+09:00"）を「2026/09/25」にする
export function formatDate(isoString: string): string {
  return DATE_FORMAT.format(new Date(isoString));
}

// 日時（"2026-09-25T10:00:00.000+09:00"）を「2026/09/25 10:00」にする。メッセージの日時に使う
export function formatDateTime(isoString: string): string {
  return DATE_TIME_FORMAT.format(new Date(isoString));
}

// 日時を、経った時間で書き分ける。通知の日時に使う（ページ設計.md の 6-5 C10。PR325）。
//   1分未満「たった今」、1時間未満「12分前」、24時間未満「3時間前」、
//   それより前は今年なら「9月20日」、去年以前なら「2025年9月20日」（年は日本時間で比べる）。
// 開いた時点の表示のままで、開いている間には変わらない（未読件数をリアルタイムで更新しないのと同じ割り切り）
export function formatRelativeTime(isoString: string, now: Date = new Date()): string {
  const date = new Date(isoString);
  // 端末の時計が遅れていて、未来の日時に見えるときも「たった今」にする
  const minutes = Math.floor((now.getTime() - date.getTime()) / 60_000);
  if (minutes < 1) return "たった今";
  if (minutes < 60) return `${minutes}分前`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}時間前`;
  return YEAR_FORMAT.format(date) === YEAR_FORMAT.format(now)
    ? MONTH_DAY_FORMAT.format(date)
    : YEAR_MONTH_DAY_FORMAT.format(date);
}

// 稼働条件の1行表示に使う、募集の項目
type WorkConditionsFields = {
  min_work_days_per_week: number | null;
  min_work_hours_per_day: number | null;
  min_duration_months: number | null;
  work_style: string | null;
  prefecture_id: number | null;
};

// 募集の稼働条件の1行表示（design/designs/その他決め事.md の 5-6「募集一覧の各行」）。
// 例：「週2日〜・1日4時間〜・3ヶ月〜・一部リモート（東京都）」。
// 空欄の項目は飛ばし、全部空欄なら「未入力」（その他決め事.md の 5-10）
export function formatWorkConditions(fields: WorkConditionsFields, options: Options): string {
  const parts: string[] = [];
  if (fields.min_work_days_per_week !== null) parts.push(`週${fields.min_work_days_per_week}日〜`);
  if (fields.min_work_hours_per_day !== null) parts.push(`1日${fields.min_work_hours_per_day}時間〜`);
  if (fields.min_duration_months !== null) parts.push(`${fields.min_duration_months}ヶ月〜`);

  // 勤務形態と勤務地は「一部リモート（東京都）」のように1つにまとめる。片方だけならその片方
  const workStyle = labelOf(options.enums.work_style, fields.work_style);
  const prefecture = nameOf(options.masters.prefectures, fields.prefecture_id);
  const place = workStyle && prefecture ? `${workStyle}（${prefecture}）` : (workStyle ?? prefecture);
  if (place) parts.push(place);

  return parts.length > 0 ? parts.join("・") : "未入力";
}

// 時給。1500 → 「時給1,500円」。空欄なら null
export function formatHourlyWage(wage: number | null): string | null {
  return wage === null ? null : `時給${wage.toLocaleString("ja-JP")}円`;
}

// 募集の開始時期。"2026-11-01" → 「2026年11月から」。空欄は「随時」（その他決め事.md の 5-6）
export function formatStartMonth(date: string | null): string {
  if (!date) return "随時";
  const [year, month] = date.split("-");
  return `${year}年${Number(month)}月から`;
}
