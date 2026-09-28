"use client";

// 通知（C10）の中身。詳しくは design/designs/ページ設計.md の 6-5 C10、API設計.md の 16-3-8 ㊷〜㊹。
// 自社宛ての「おすすめの学生」の通知を、新しい順に20件ずつ並べる（Rails が選んで並べる）。ページは URL の ?page= に持つ。
// 行を押すと既読にして（㊸）、リンク先（学生詳細）へ移る。「すべて既読にする」（㊹）で未読をまとめて既読にする。
// ヘッダーの未読件数は、共通の枠が画面を移るたびに取り直す。画面を移らない操作（すべて既読など）のあとは、ここで取り直しを頼む

import { useState, type ReactNode } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useMe, useRedirectIfUnauthorized, useRefreshMe } from "@/components/member-only";
import { PageNav } from "@/components/page-nav";
import { PageTitle } from "@/components/page-title";
import { Button } from "@/components/ui/button";
import { ApiError, apiFetch, useApi } from "@/lib/api";
import { isAppPathFor } from "@/lib/auth";
import { formatRelativeTime } from "@/lib/format";
import type { NotificationListResult, NotificationRow as Notification } from "@/lib/notifications";
import { cn } from "@/lib/utils";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

const PAGE_PATH = "/company/notifications";

// ページ → 画面の URL。1ページ目なら page を付けない
function pageUrl(page: number): string {
  return page > 1 ? `${PAGE_PATH}?page=${page}` : PAGE_PATH;
}

export function CompanyNotificationList() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const me = useMe();
  const refreshMe = useRefreshMe();
  const redirectIfUnauthorized = useRedirectIfUnauthorized();
  // URL の ?page= を読む。数でなければ1ページ目（Rails も同じ扱い）
  const requestedPage = Number(searchParams.get("page"));
  const page = Number.isInteger(requestedPage) && requestedPage > 1 ? requestedPage : 1;

  // 401 は共通の枠（member-only.tsx）がログイン画面へ移す。
  // keepPreviousData：次の結果が届くまで前の結果を出したままにする（ページを変えたときに画面がちらつかないように）。
  // mutate：取り直す関数（既読にしたあとに使う）
  const { data, error, mutate } = useApi<NotificationListResult>(
    `/api/company/notifications${page > 1 ? `?page=${page}` : ""}`,
    { keepPreviousData: true },
  );
  // 送信中か（既読・すべて既読）。二度押しを防ぐため、送っている間はほかの行とボタンも押せなくする
  const [sending, setSending] = useState(false);
  // 送信に失敗したときの一言
  const [message, setMessage] = useState<string | null>(null);

  // 既読にしたあと、画面を移らないときの後片付け。一覧（既読の見た目）とヘッダーの件数を取り直す
  async function refreshAfterRead() {
    await mutate();
    await refreshMe().catch(() => undefined);
  }

  // 送信を1つ行う。失敗したら一言を出し、false を返す（401 ならログイン画面へ移す）
  async function send(path: string): Promise<boolean> {
    try {
      await apiFetch<null>(path, { method: "POST" });
      return true;
    } catch (sendError) {
      if (redirectIfUnauthorized(sendError)) return false;
      setMessage(sendError instanceof ApiError ? sendError.message : FALLBACK_ERROR_MESSAGE);
      return false;
    }
  }

  // 行を押したとき：未読なら既読にして（㊸）、リンク先がアプリ内のパスならそこへ移る
  async function openNotification(notification: Notification) {
    setMessage(null);
    setSending(true);
    try {
      if (notification.read_at === null && !(await send(`/api/company/notifications/${notification.id}/read`))) return;
      // 外部のサイトへのリンクを通知に仕込めないように、企業の画面のパスのときだけ移る（PR326）。
      // 移った先の画面で共通の枠がログイン中の人を取り直すので、ヘッダーの件数もそこで新しくなる
      if (isAppPathFor("company", notification.link_path)) {
        router.push(notification.link_path);
        return;
      }
      await refreshAfterRead();
    } finally {
      setSending(false);
    }
  }

  // 「すべて既読にする」（㊹）
  async function readAll() {
    setMessage(null);
    setSending(true);
    try {
      if (await send("/api/company/notifications/read_all")) await refreshAfterRead();
    } finally {
      setSending(false);
    }
  }

  let content: ReactNode;
  if (!data && error && error.status !== 401) {
    content = <p className="text-sm text-destructive">{error.message}</p>;
  } else if (!data) {
    content = <p className="text-sm text-muted-foreground">読み込み中…</p>;
  } else if (data.pagination.total_count === 0) {
    content = <p className="text-sm text-muted-foreground">通知はありません</p>;
  } else if (data.items.length === 0) {
    // 範囲外のページ（URL を手で書き換えたときなど）
    content = <p className="text-sm text-muted-foreground">このページに通知はありません</p>;
  } else {
    content = (
      <>
        <ul className="divide-y rounded-lg border">
          {data.items.map((notification) => (
            <NotificationItem
              key={notification.id}
              notification={notification}
              disabled={sending}
              onOpen={() => void openNotification(notification)}
            />
          ))}
        </ul>
        <PageNav page={data.pagination.page} totalPages={data.pagination.total_pages} hrefFor={pageUrl} />
      </>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-4">
        <PageTitle>通知</PageTitle>
        {/* 未読が1件もなければ押せない。件数はヘッダーと同じ値（③ の unread_notifications_count） */}
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="ml-auto"
          disabled={sending || !me.unread_notifications_count}
          onClick={() => void readAll()}
        >
          すべて既読にする
        </Button>
      </div>

      {message && <p className="text-sm text-destructive">{message}</p>}

      {content}
    </div>
  );
}

// ── 行 ──
// 部品は、画面の部品の中ではなく、このファイルの一番上の段に置く

type NotificationItemProps = {
  notification: Notification;
  disabled: boolean;
  onOpen: () => void;
};

// 通知1件の行。行全体が1つのボタンで、押すと既読にしてリンク先へ移る。
// 未読の行は、背景色と丸い印で区別する（ページ設計.md の 6-5 C10）
function NotificationItem({ notification, disabled, onOpen }: NotificationItemProps) {
  const unread = notification.read_at === null;

  return (
    <li>
      <button
        type="button"
        disabled={disabled}
        onClick={onOpen}
        className={cn(
          "flex w-full items-start gap-3 px-4 py-3 text-left text-sm hover:bg-muted disabled:cursor-wait",
          unread && "bg-muted/60",
        )}
      >
        {/* 未読の印。既読の行も同じ幅を空けて、本文の頭をそろえる */}
        <span className="mt-1.5 size-2 shrink-0 rounded-full" aria-hidden="true">
          {unread && <span className="block size-2 rounded-full bg-primary" />}
        </span>
        <span className="flex-1 space-y-1">
          <span className={cn("block", unread && "font-bold")}>
            {unread && <span className="sr-only">未読：</span>}
            {notification.body}
          </span>
          <span className="block text-muted-foreground">{formatRelativeTime(notification.created_at)}</span>
        </span>
      </button>
    </li>
  );
}
