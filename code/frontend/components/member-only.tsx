"use client";

// ログイン後の画面の枠の中身。
// 開いたら /api/me を呼び、未ログインならログイン画面へ（開こうとしていたページを return_to に付ける）、
// 種別が違えば相手の種別のホームへ移す。ログイン中の人は、中の画面から useMe() で取り出せる。
// これは見た目のための振り分けで、守りは Rails が行う（design/designs/API設計.md の 16-1-6）

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { usePathname, useRouter } from "next/navigation";
import { ApiError } from "@/lib/api";
import { fetchMe, homePathFor, loginUrlWithReturnTo, type Me, type Role } from "@/lib/auth";

// ログイン中の人を、枠の中のどの画面・部品からでも取り出せるようにする入れ物
// （Django で、ビューが request.user をテンプレートに渡しておくのと同じ役割）
const MeContext = createContext<Me | null>(null);

// ログイン中の人を取り出す。MemberOnly の中の画面・部品からだけ使える
export function useMe(): Me {
  const me = useContext(MeContext);
  if (!me) {
    throw new Error("useMe は MemberOnly の中でだけ使えます");
  }
  return me;
}

export function MemberOnly({ role, children }: { role: Role; children: ReactNode }) {
  const router = useRouter();
  // 今の画面の URL。ログイン後の画面どうしを移ったことに気づくために使う
  const pathname = usePathname();
  const [me, setMe] = useState<Me | null>(null);
  const [failed, setFailed] = useState(false);

  // 画面を開いたときと、ログイン後の画面の中で別の画面へ移ったときに、/api/me を呼ぶ（16-2 の「すべての画面で開いたときに呼ぶ」）。
  // Next.js では画面を移っても共通の枠は作り直されないので、URL が変わるたびに呼び直す。
  // 2回目以降は、画面を出したまま裏で確かめる
  useEffect(() => {
    // 画面を離れた後に返事が来たときは、何もしない
    let active = true;

    fetchMe()
      .then((fetched) => {
        if (!active) return;
        if (fetched.role !== role) {
          // 種別が違う（学生が企業の画面を開いた、など）。相手の種別のホームへ移す
          router.replace(homePathFor(fetched.role));
          return;
        }
        setMe(fetched);
        setFailed(false);
      })
      .catch((error: unknown) => {
        if (!active) return;
        if (error instanceof ApiError && error.status === 401) {
          // 未ログイン。今のページ（? の後ろも含む）を return_to に付けて、ログイン画面へ移す
          router.replace(loginUrlWithReturnTo(role, window.location.pathname + window.location.search));
          return;
        }
        setFailed(true);
      });

    return () => {
      active = false;
    };
  }, [pathname, role, router]);

  if (failed) {
    // 16-1-10 の 500 の文言
    return <p className="p-8 text-sm text-destructive">エラーが起きました</p>;
  }

  if (!me) {
    // 最初の確認が終わるまで（API設計.md の 16-1-1 の割り切り）
    return <p className="p-8 text-sm text-muted-foreground">読み込み中…</p>;
  }

  return <MeContext value={me}>{children}</MeContext>;
}
