// 新規登録の画面の外枠と、アイコンだけ保存できなかったときの画面。企業（C9）と学生（S9）で共通
// （design/designs/ページ設計.md の 6-5 C9・6-6 S9、API設計.md の 16-3 ⑤⑥）

import type { ReactNode } from "react";
import Link from "next/link";
import { RequiredNote } from "@/components/form-fields";
import { PageTitle } from "@/components/page-title";
import { buttonVariants } from "@/components/ui/button";
import { homePathFor, loginPathFor, type Role } from "@/lib/auth";

// 種別ごとの文言
const TEXTS: Record<Role, { title: string; profileScreen: string }> = {
  company: { title: "新規登録（企業用）", profileScreen: "会社情報" },
  student: { title: "新規登録（学生用）", profileScreen: "マイページ" },
};

// 外枠：題名と「＊は必須項目です」、中身（ステップ）、ログイン画面へのリンク
export function SignupLayout({ role, children }: { role: Role; children: ReactNode }) {
  return (
    <main className="mx-auto mt-16 w-full max-w-3xl space-y-6 px-4 pb-16">
      <div className="space-y-2">
        <PageTitle>{TEXTS[role].title}</PageTitle>
        <RequiredNote />
      </div>

      {children}

      <p className="text-sm">
        <Link href={loginPathFor(role)} className="underline">
          すでにアカウントをお持ちの方はこちら
        </Link>
      </p>
    </main>
  );
}

// 登録はできた（ログインした状態）が、アイコンだけ保存できなかったとき（PR229）。
// すぐにホームへ移ると一言を読む前に消えるので、利用者が「募集一覧へ進む」を押して進む
export function SignupIconFailed({ role }: { role: Role }) {
  return (
    <main className="mx-auto mt-16 w-full max-w-3xl space-y-6 px-4 pb-16">
      <PageTitle>{TEXTS[role].title}</PageTitle>
      <p className="text-sm">登録が完了しました。</p>
      <p className="text-sm text-destructive">
        アイコンを保存できませんでした。あとで{TEXTS[role].profileScreen}から登録してください
      </p>
      {/* replace：ブラウザの「戻る」で登録の画面に戻らない */}
      <Link href={homePathFor(role)} replace className={buttonVariants()}>
        募集一覧へ進む
      </Link>
    </main>
  );
}
