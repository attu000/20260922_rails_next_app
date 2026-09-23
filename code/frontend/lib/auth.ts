// ログイン中の人と、画面の行き先の決め方。
// 詳しくは design/designs/API設計.md の 16-1-6（ログインの確認と振り分け）、16-1-13（画面の URL）、16-3-2（形A）

import { apiFetch } from "@/lib/api";

export type Role = "company" | "student";

// 形A：ログイン中の人（16-3-2）。Rails の app/views/api/me/show.json.jbuilder と同じ形
export type Me = {
  id: number;
  role: Role;
  // 企業なら会社名、学生なら氏名
  name: string | null;
  // アイコンの URL。未登録なら null
  icon_url: string | null;
  // 企業なら未読の通知の件数、学生なら null
  unread_notifications_count: number | null;
};

// ログイン中の人を取る（③ GET /api/me）。未ログインなら ApiError（401）が投げられる
export function fetchMe(): Promise<Me> {
  return apiFetch<Me>("/api/me");
}

// 種別ごとのホーム（企業は募集一覧、学生は募集一覧（募集検索））
const HOME_PATHS: Record<Role, string> = {
  company: "/company/job_postings",
  student: "/student/job_postings",
};

// 種別ごとのログイン画面
const LOGIN_PATHS: Record<Role, string> = {
  company: "/company/login",
  student: "/student/login",
};

// 種別ごとの画面の URL の先頭
const PATH_PREFIXES: Record<Role, string> = {
  company: "/company/",
  student: "/student/",
};

export function homePathFor(role: Role): string {
  return HOME_PATHS[role];
}

export function loginPathFor(role: Role): string {
  return LOGIN_PATHS[role];
}

// ログイン画面へ移すときの URL。開こうとしていたページを return_to に付ける。
// 例："/company/login?return_to=%2Fcompany%2Fstudents%2F5"
export function loginUrlWithReturnTo(role: Role, currentPath: string): string {
  return `${loginPathFor(role)}?return_to=${encodeURIComponent(currentPath)}`;
}

// ログインした後の行き先。
// return_to は利用者が自由に書き換えられるので、ログインした人の種別と先頭が合っているときだけ使う。
// 「/company/ か /student/ で始まるか」の確認で、「/ で始まるアプリ内のパスだけ」の決まりも同時に満たす
// （「//別のサイト」のような書き方は、どちらでも始まらないので捨てられる）。
// これは見た目のための処理で、書き換えられても他人のデータは見えない（Rails が断る）
export function destinationAfterLogin(role: Role, returnTo: string | null): string {
  if (returnTo && returnTo.startsWith(PATH_PREFIXES[role])) {
    return returnTo;
  }
  return homePathFor(role);
}
