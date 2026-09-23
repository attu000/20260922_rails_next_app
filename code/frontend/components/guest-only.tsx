"use client";

// ログイン前の画面（ログイン、新規登録）の枠の中身。
// 開いたら /api/me を呼び、ログイン済みなら種別ごとのホームへ移す。未ログインならそのまま画面を出す。
// これは見た目のための振り分けで、守りは Rails が行う（design/designs/API設計.md の 16-1-6）

import { useEffect, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { fetchMe, homePathFor } from "@/lib/auth";

export function GuestOnly({ children }: { children: ReactNode }) {
  const router = useRouter();
  // 確かめ終わるまで画面を出さない。こうすると、合言葉の Cookie が届く前にログインを押されることがない（16-1-7）
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    // 画面を離れた後に返事が来たときは、何もしない
    let active = true;

    fetchMe()
      .then((me) => {
        // ログイン済み。replace で移すので、ブラウザの「戻る」でこの画面に戻らない
        if (active) router.replace(homePathFor(me.role));
      })
      .catch(() => {
        // 401 は「未ログインという普通の状態」なので、移動せずに画面を出す（16-1-6）。
        // 401 以外の失敗も画面を出す（ログインを押したときに、フォームの側でエラーの一言が出る）
        if (active) setChecking(false);
      });

    return () => {
      active = false;
    };
  }, [router]);

  if (checking) {
    // 画面を開いた直後に一瞬出る（API設計.md の 16-1-1 の割り切り）
    return <p className="p-8 text-sm text-gray-500">読み込み中…</p>;
  }

  return <>{children}</>;
}
