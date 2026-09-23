"use client";

// トップ（/）。振り分けだけの画面で、中身はない（design/designs/API設計.md の 16-1-6・16-1-13）。
// ログイン中なら種別ごとのホームへ、未ログインなら学生のログイン画面へ移す

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { fetchMe, homePathFor, loginPathFor } from "@/lib/auth";

export default function TopPage() {
  const router = useRouter();

  useEffect(() => {
    // 画面を離れた後に返事が来たときは、何もしない
    let active = true;

    fetchMe()
      .then((me) => {
        if (active) router.replace(homePathFor(me.role));
      })
      .catch(() => {
        if (active) router.replace(loginPathFor("student"));
      });

    return () => {
      active = false;
    };
  }, [router]);

  return <p className="p-8 text-sm text-gray-500">読み込み中…</p>;
}
