"use client";

// ログインのフォーム。企業用（C8）・学生用（S8）で共通（design/designs/ページ設計.md の 6-5・6-6）。
// 認証の処理は企業・学生で共通。ログインした人の種別で行き先を決める（企業用の画面から学生がログインしたら、学生のホームへ）。
// 見た目は最小限にしている。見た目の方針は Phase 6 の最初に決める

import { useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { ApiError, apiFetch } from "@/lib/api";
import { destinationAfterLogin, loginPathFor, type Me, type Role } from "@/lib/auth";

// 画面ごとに変わる文言とリンク先
const SCREEN_TEXTS: Record<Role, { title: string; signupPath: string; otherLabel: string; otherRole: Role }> = {
  company: {
    title: "ログイン（企業用）",
    signupPath: "/company/signup",
    otherLabel: "学生の方はこちら",
    otherRole: "student",
  },
  student: {
    title: "ログイン（学生用）",
    signupPath: "/student/signup",
    otherLabel: "企業の方はこちら",
    otherRole: "company",
  },
};

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

export function LoginForm({ role }: { role: Role }) {
  const router = useRouter();
  // URL の ? の後ろ（Django の request.GET にあたる）
  const searchParams = useSearchParams();
  const texts = SCREEN_TEXTS[role];

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で送る
    event.preventDefault();
    // 2回押しても、1回だけ送る
    if (submitting) return;

    setSubmitting(true);
    setErrorMessage(null);

    try {
      // ① POST /api/session。返事は形A（ログインした人）
      const me = await apiFetch<Me>("/api/session", { method: "POST", body: { email, password } });
      // 行き先は、ログインした人の種別と return_to から決める（16-1-6）。
      // destinationAfterLogin は /company/ か /student/ で始まる行き先しか返さないので、
      // 書き換えられた return_to（javascript: など）を router.replace に渡すことはない
      router.replace(destinationAfterLogin(me.role, searchParams.get("return_to")));
    } catch (error) {
      // Rails の一言をそのまま出す（16-1-10）。401「ログインができません」、429「しばらくしてからお試しください」など
      setErrorMessage(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
      setSubmitting(false);
    }
  }

  return (
    <main className="mx-auto mt-16 max-w-sm space-y-6 px-4">
      <h1 className="text-xl font-bold">{texts.title}</h1>

      {/* noValidate：ブラウザの入力チェックを止める。
          ログイン画面では、失敗したら「ログインができません」とだけ出すと決めているため（権限_バリデーション.md の 17-3-1） */}
      <form onSubmit={handleSubmit} noValidate className="space-y-4">
        <div className="space-y-1">
          <label htmlFor="email" className="block text-sm">
            メールアドレス
          </label>
          <input
            id="email"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            className="w-full rounded border px-3 py-2"
          />
        </div>

        <div className="space-y-1">
          <label htmlFor="password" className="block text-sm">
            パスワード
          </label>
          <input
            id="password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            className="w-full rounded border px-3 py-2"
          />
        </div>

        {errorMessage && <p className="text-sm text-red-600">{errorMessage}</p>}

        <button type="submit" className="w-full rounded bg-gray-900 px-4 py-2 text-white">
          {submitting ? "ログイン中…" : "ログイン"}
        </button>
      </form>

      <div className="space-y-2 text-sm">
        {/* 新規登録（C9・S9）は Phase 6 で作る。それまでは押すと「見つかりません」になる */}
        <p>
          <Link href={texts.signupPath} className="underline">
            新規登録はこちら
          </Link>
        </p>
        <p>
          <Link href={loginPathFor(texts.otherRole)} className="underline">
            {texts.otherLabel}
          </Link>
        </p>
      </div>
    </main>
  );
}
