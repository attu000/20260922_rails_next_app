"use client";

// ログイン後の画面の枠の中身。
// 開いたら /api/me を呼び、未ログインならログイン画面へ（開こうとしていたページを return_to に付ける）、
// 種別が違えば相手の種別のホームへ移す。中の画面からは、次の3つを使える。
// - useMe()：ログイン中の人  - useRefreshMe()：それを取り直す  - useRedirectIfUnauthorized()：API の 401 でログイン画面へ移す
// 中の画面が SWR（useApi）でデータを取って 401 になったときも、ここでまとめてログイン画面へ移す。
// これは見た目のための振り分けで、守りは Rails が行う（design/designs/API設計.md の 16-1-6）

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { usePathname, useRouter } from "next/navigation";
import { SWRConfig, type SWRConfiguration } from "swr";
import { ApiError } from "@/lib/api";
import { fetchMe, homePathFor, loginUrlWithReturnTo, type Me, type Role } from "@/lib/auth";

// ログイン中の人を、枠の中のどの画面・部品からでも取り出せるようにする入れ物
// （Django で、ビューが request.user をテンプレートに渡しておくのと同じ役割）
// 中身は「ログイン中の人」と「それを取り直す関数」
type MemberContextValue = {
  me: Me;
  refreshMe: () => Promise<void>;
};

const MeContext = createContext<MemberContextValue | null>(null);

function useMemberContext(): MemberContextValue {
  const value = useContext(MeContext);
  if (!value) {
    throw new Error("useMe などは MemberOnly の中でだけ使えます");
  }
  return value;
}

// ログイン中の人を取り出す。MemberOnly の中の画面・部品からだけ使える
export function useMe(): Me {
  return useMemberContext().me;
}

// ログイン中の人（ヘッダーの名前・アイコン）を取り直す関数を取り出す。
// 企業プロフィールで会社名やアイコンを保存した後に呼ぶ。
// Next.js では画面を移らない限り共通の枠が作り直されないので、保存した画面から取り直しを頼む
export function useRefreshMe(): () => Promise<void> {
  return useMemberContext().refreshMe;
}

// API から 401 が返ってきたら、ログイン画面へ移す関数を取り出す（16-1-6：ログイン後の画面では、どの API の 401 でも移す）。
// 別のタブでログアウトした場合などに起きる。移したら true を返すので、呼んだ側はそれ以上何もしない
export function useRedirectIfUnauthorized(): (error: unknown) => boolean {
  const router = useRouter();
  const { me } = useMemberContext();

  return useCallback(
    (error: unknown) => {
      if (error instanceof ApiError && error.status === 401) {
        // 今のページ（? の後ろも含む）を return_to に付ける
        router.replace(loginUrlWithReturnTo(me.role, window.location.pathname + window.location.search));
        return true;
      }
      return false;
    },
    [router, me.role],
  );
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

  // ログイン中の人を取り直す。失敗したとき（401 など）の扱いは、呼んだ側に任せる
  const refreshMe = useCallback(async () => {
    setMe(await fetchMe());
  }, []);

  // 中身が変わったときだけ作り直す（毎回作り直すと、中の画面がすべて描き直されるため）
  const contextValue = useMemo(() => (me ? { me, refreshMe } : null), [me, refreshMe]);

  // 中の画面の SWR の共通設定。データを取って 401 になったら（別のタブでログアウトした、など）、ログイン画面へ移す。
  // ログイン前の画面はこの外側なので、移さない（16-1-6）
  const swrConfig = useMemo<SWRConfiguration>(
    () => ({
      onError: (error: unknown) => {
        if (error instanceof ApiError && error.status === 401) {
          router.replace(loginUrlWithReturnTo(role, window.location.pathname + window.location.search));
        }
      },
    }),
    [router, role],
  );

  if (failed) {
    // 16-1-10 の 500 の文言
    return <p className="p-8 text-sm text-destructive">エラーが起きました</p>;
  }

  if (!contextValue) {
    // 最初の確認が終わるまで（API設計.md の 16-1-1 の割り切り）
    return <p className="p-8 text-sm text-muted-foreground">読み込み中…</p>;
  }

  return (
    <MeContext value={contextValue}>
      <SWRConfig value={swrConfig}>{children}</SWRConfig>
    </MeContext>
  );
}
