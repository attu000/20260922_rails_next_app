"use client";

// メッセージ管理（C7 企業・S5 学生）の中身。詳しくは design/designs/ページ設計.md の 6-5 C7・6-6 S5、
// API設計.md の 16-3-7（㊱〜㊶）、権限_バリデーション.md の 17-2-3。
// 企業と学生で違うのは、相手の種類（学生か企業か）と窓口の住所だけなので、違いを SETTINGS にまとめ、1つの部品で出す。
//   - 左（狭い画面では上）：スレッド一覧（最後のメッセージの新しい順。Rails が並べる）
//   - 右（狭い画面では下）：選んだ相手とのチャットと、送信欄
// 選んだ相手とページは、URL の ?student_id=（学生なら ?company_id=）と ?page= に持つ（URL が正。16-1-13）。
// 候補者一覧・学生詳細・募集詳細・企業詳細のメッセージのボタンから来たときは、その相手のスレッドが開いた状態になる。
// リアルタイム更新はしない。送ったメッセージは返事をそのまま末尾に足し、相手からの新しいメッセージは開き直したときに取る（16-3-7）。
// 学生の画面では、まだマッチしていないスカウトがあれば、チャットの下の方に「マッチする」を出す（PR222・PR223）。
// 次のものは【仕上げ】で足す
//   - チャットの上部の「マッチしている募集」
//   - 相手の名前から学生詳細・企業詳細へのリンク

import { useState, type FormEvent, type ReactNode } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { cn } from "cn";
import { LONG_TEXT_MAX_LENGTH, toFieldErrorItems } from "@/components/form-fields";
import { useRedirectIfUnauthorized } from "@/components/member-only";
import { PageNav } from "@/components/page-nav";
import { PageTitle } from "@/components/page-title";
import { ProfileIcon } from "@/components/profile-icon";
import { StatusBadge } from "@/components/status-badge";
import { ReasonsDialog } from "@/components/student-candidacy-actions";
import { Button } from "@/components/ui/button";
import { Field, FieldDescription, FieldError, FieldLabel } from "@/components/ui/field";
import { Textarea } from "@/components/ui/textarea";
import { ApiError, apiFetch, useApi } from "@/lib/api";
import { formatDateTime } from "@/lib/format";
import type {
  MatchableScout,
  Message,
  MessageThreadDetail,
  MessageThreadListResult,
  MessageThreadRow,
} from "@/lib/messages";
import { useOptions } from "@/lib/options";
import type { MyCandidacyStatus } from "@/lib/student-job-postings";

// 通信そのものに失敗したとき（Rails の message がないとき）の一言
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// 本文が空のまま送ろうとしたときの文言。Rails の 422 と同じ（権限_バリデーション.md の 17-3-3）
const BODY_REQUIRED_MESSAGE = "本文を入力してください";

// 相手の種類ごとの違い
const SETTINGS = {
  company: {
    // 画面の住所
    pagePath: "/company/messages",
    // 開く相手の番号を入れる、URL の ? の後ろの名前
    partnerParam: "student_id",
    // ㊱ スレッド一覧
    threadsApiPath: "/api/company/message_threads",
    // ㊲ チャット（この後ろに /messages を付けると ㊳ 送信）
    threadApiPath: (partnerId: string) => `/api/company/students/${encodeURIComponent(partnerId)}/message_thread`,
    // まだ送れないとき（スカウトの返事待ち）に、送信欄の下に出す一言
    cannotSendMessage: "この学生とマッチすると、メッセージを送れるようになります",
  },
  student: {
    pagePath: "/student/messages",
    partnerParam: "company_id",
    // ㊴ スレッド一覧
    threadsApiPath: "/api/student/message_threads",
    // ㊵ チャット（この後ろに /messages を付けると ㊶ 送信）
    threadApiPath: (partnerId: string) => `/api/student/companies/${encodeURIComponent(partnerId)}/message_thread`,
    cannotSendMessage: "この企業とマッチすると、メッセージを送れるようになります",
  },
} as const;

type MessageCenterSettings = (typeof SETTINGS)[keyof typeof SETTINGS];

// 相手の番号とページ → ? の後ろ。相手を選んでいなければ付けず、1ページ目は page を付けない
function buildQuery(settings: MessageCenterSettings, partnerId: string | null, page: number): string {
  const params = new URLSearchParams();
  if (partnerId !== null) params.set(settings.partnerParam, partnerId);
  if (page > 1) params.set("page", String(page));
  return params.toString();
}

// ? の後ろ → 画面の URL
function pageUrl(settings: MessageCenterSettings, query: string): string {
  return query === "" ? settings.pagePath : `${settings.pagePath}?${query}`;
}

type MessageCenterProps = {
  // "company"（企業のメッセージ管理）か "student"（学生のメッセージ管理）
  kind: keyof typeof SETTINGS;
};

export function MessageCenter({ kind }: MessageCenterProps) {
  const settings = SETTINGS[kind];
  const searchParams = useSearchParams();
  // 開いている相手の番号。URL の番号は利用者が書き換えられるが、そのまま Rails に渡す（見てよい範囲の外なら Rails が 404）
  const partnerId = searchParams.get(settings.partnerParam) || null;
  // URL の ?page= を読む。数でなければ1ページ目（Rails も同じ扱い）
  const requestedPage = Number(searchParams.get("page"));
  const page = Number.isInteger(requestedPage) && requestedPage > 1 ? requestedPage : 1;

  // 401 は共通の枠（member-only.tsx）がログイン画面へ移す。
  // keepPreviousData：次のページが届くまで前のページを出したままにする（ページ送りで画面がちらつかないように）。
  // mutate：取り直す関数（メッセージを送ったあと、並び順と日時が変わるので取り直す）
  const {
    data: threads,
    error: threadsError,
    mutate: mutateThreads,
  } = useApi<MessageThreadListResult>(`${settings.threadsApiPath}${page > 1 ? `?page=${page}` : ""}`, {
    keepPreviousData: true,
  });

  let threadList: ReactNode;
  if (!threads && threadsError && threadsError.status !== 401) {
    threadList = <p className="text-sm text-destructive">{threadsError.message}</p>;
  } else if (!threads) {
    threadList = <p className="text-sm text-muted-foreground">読み込み中…</p>;
  } else if (threads.pagination.total_count === 0) {
    threadList = <p className="text-sm text-muted-foreground">まだメッセージのやりとりはありません</p>;
  } else if (threads.items.length === 0) {
    // 範囲外のページ（URL を手で書き換えたときなど）
    threadList = <p className="text-sm text-muted-foreground">このページにメッセージはありません</p>;
  } else {
    threadList = (
      <>
        <ul className="space-y-1">
          {threads.items.map((thread) => (
            <ThreadRow
              key={thread.id}
              thread={thread}
              selected={String(thread.partner.id) === partnerId}
              // 相手を変えても、今のページのまま
              href={pageUrl(settings, buildQuery(settings, String(thread.partner.id), page))}
            />
          ))}
        </ul>
        <PageNav
          page={threads.pagination.page}
          totalPages={threads.pagination.total_pages}
          // 開いている相手はそのまま、ページだけ変える
          hrefFor={(nextPage) => pageUrl(settings, buildQuery(settings, partnerId, nextPage))}
        />
      </>
    );
  }

  return (
    <div className="space-y-6">
      <PageTitle>メッセージ</PageTitle>

      {/* 広い画面では左右、狭い画面では上下に並べる */}
      <div className="grid gap-6 md:grid-cols-[16rem_1fr]">
        <section aria-label="スレッド一覧" className="space-y-3">
          {threadList}
        </section>

        <section aria-label="チャット" className="min-w-0">
          {partnerId === null ? (
            <p className="text-sm text-muted-foreground">一覧から相手を選んでください</p>
          ) : (
            // 相手を変えたら、入力中の本文やエラーも消えるよう、相手の番号で作り直す（key）
            <ChatPanel
              key={partnerId}
              settings={settings}
              partnerId={partnerId}
              onSent={() => void mutateThreads()}
            />
          )}
        </section>
      </div>
    </div>
  );
}

// ── 部品 ──
// 部品は、画面の部品の中ではなく、このファイルの一番上の段に置く

type ThreadRowProps = {
  thread: MessageThreadRow;
  // 今開いている相手か
  selected: boolean;
  href: string;
};

// スレッド一覧の1行。アイコン・相手の名前・最後のメッセージの日時
function ThreadRow({ thread, selected, href }: ThreadRowProps) {
  return (
    <li>
      <Link
        href={href}
        aria-current={selected ? "page" : undefined}
        className={cn(
          "flex items-center gap-3 rounded-lg px-3 py-2 hover:bg-muted",
          selected && "bg-secondary hover:bg-secondary",
        )}
      >
        <ProfileIcon src={thread.partner.icon_url} name={thread.partner.name} size="sm" />
        <span className="min-w-0">
          <span className="block truncate text-sm font-bold">{thread.partner.name}</span>
          <span className="block text-xs text-muted-foreground">
            {thread.last_message_at === null ? "メッセージはまだありません" : formatDateTime(thread.last_message_at)}
          </span>
        </span>
      </Link>
    </li>
  );
}

type ChatPanelProps = {
  settings: MessageCenterSettings;
  partnerId: string;
  // メッセージを送れたとき（スレッド一覧を取り直すため）
  onSent: () => void;
};

// 選んだ相手とのチャット。上に相手、中にメッセージ（古い順）、下に送信欄
function ChatPanel({ settings, partnerId, onSent }: ChatPanelProps) {
  const threadPath = settings.threadApiPath(partnerId);
  // mutate：覚えている中身を書き換える・取り直す関数（送ったメッセージを末尾に足すときと、409 のあとに使う）
  const { data, error, mutate } = useApi<MessageThreadDetail>(threadPath);

  // スレッドがない相手や、見てよい範囲の外の番号なら、Rails の一言（「見つかりません」）をそのまま出す
  if (!data && error && error.status !== 401) {
    return <p className="text-sm text-destructive">{error.message}</p>;
  }
  if (!data) {
    return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  }

  // 送れたとき：返ってきたメッセージを会話の末尾に足す（読み直さない）。スレッド一覧は取り直す
  function handleSent(message: Message) {
    void mutate(
      (current) => (current ? { ...current, messages: [...current.messages, message] } : current),
      { revalidate: false },
    );
    onSent();
  }

  // スカウトにマッチできたとき：送れるか・マッチできるスカウトが変わるので、チャットを取り直す。
  // スレッド一覧も、送ったときと同じく取り直す
  function handleMatched() {
    void mutate();
    onSent();
  }

  return (
    <div className="space-y-4 rounded-lg border p-4">
      <div className="flex items-center gap-2">
        <ProfileIcon src={data.partner.icon_url} name={data.partner.name} size="sm" />
        <h2 className="font-bold">{data.partner.name}</h2>
      </div>

      {data.messages.length === 0 ? (
        <p className="text-sm text-muted-foreground">まだメッセージはありません</p>
      ) : (
        <ul className="space-y-4">
          {data.messages.map((message) => (
            <MessageItem key={message.id} message={message} />
          ))}
        </ul>
      )}

      {/* 学生のチャットだけが返す。まだマッチしていないスカウトがあれば、送信欄のすぐ上に出す（PR222） */}
      {data.matchable_scouts && data.matchable_scouts.length > 0 && (
        <MatchableScouts
          scouts={data.matchable_scouts}
          onMatched={handleMatched}
          // できなかったとき（409 など）は、最新の状態に取り直す
          onFailed={() => void mutate()}
        />
      )}

      <MessageForm
        canSend={data.can_send}
        sendPath={`${threadPath}/messages`}
        cannotSendMessage={settings.cannotSendMessage}
        onSent={handleSent}
        // 409（別の画面で状態が変わったなど）のあとは、送れるかを含めて取り直す
        onConflict={() => void mutate()}
      />
    </div>
  );
}

// メッセージ1件。自分のものは右、相手のものは左に寄せる。スカウト文には、どの募集のスカウトかの札を付ける
function MessageItem({ message }: { message: Message }) {
  return (
    <li className={cn("flex flex-col gap-1", message.is_mine ? "items-end" : "items-start")}>
      {message.scout && <StatusBadge size="sm">{`募集「${message.scout.job_posting.title}」のスカウト`}</StatusBadge>}
      {/* 改行はそのまま出し、長い URL などは枠の中で折り返す */}
      <p
        className={cn(
          "max-w-[85%] rounded-lg px-3 py-2 text-sm break-words whitespace-pre-wrap",
          message.is_mine ? "bg-primary text-primary-foreground" : "bg-muted",
        )}
      >
        {message.body}
      </p>
      <span className="text-xs text-muted-foreground">{formatDateTime(message.created_at)}</span>
    </li>
  );
}

type MatchableScoutsProps = {
  scouts: MatchableScout[];
  onMatched: () => void;
  onFailed: () => void;
};

// 学生のチャットの「届いているスカウト」の枠（PR222）。募集ごとに1行ずつ「マッチする」を出す（PR223）。
// どのスカウトを出すかは Rails が判定する（募集詳細の「マッチする」と同じ判定。16-1-9）。
// 押すと、募集詳細と同じ「理由を選ぶポップアップ」を出す（項目と文言は応募と同じ。PR218）
function MatchableScouts({ scouts, onMatched, onFailed }: MatchableScoutsProps) {
  // 理由の選択肢（⑦ の enums.candidacy_reason）。この枠を出すときだけ取る
  const { options, failed } = useOptions();
  // マッチできなかったときの一言（「この操作は今はできません…」など）。取り直して行が消えても出したままにする
  const [message, setMessage] = useState<string | null>(null);

  let rows: ReactNode;
  if (failed) {
    rows = <p className="text-sm text-destructive">{FALLBACK_ERROR_MESSAGE}</p>;
  } else if (!options) {
    rows = <p className="text-sm text-muted-foreground">読み込み中…</p>;
  } else {
    rows = (
      <ul className="space-y-2">
        {scouts.map((scout) => (
          <li key={scout.candidacy_id} className="flex flex-wrap items-center justify-between gap-2">
            <span className="text-sm">募集「{scout.job_posting.title}」のスカウト</span>
            <ReasonsDialog
              triggerLabel="マッチする"
              reasonOptions={options.enums.candidacy_reason}
              // ㉜ スカウトにマッチする。返事は自分の状態（形E）だが、ここではチャットを取り直すので使わない
              submit={(reasons) =>
                apiFetch<MyCandidacyStatus>(`/api/student/candidacies/${scout.candidacy_id}/match`, {
                  method: "POST",
                  body: { reasons },
                })
              }
              onDone={() => {
                setMessage(null);
                onMatched();
              }}
              onFailed={(failedMessage) => {
                setMessage(failedMessage);
                onFailed();
              }}
            />
          </li>
        ))}
      </ul>
    );
  }

  return (
    <section aria-label="届いているスカウト" className="space-y-2 rounded-lg bg-muted p-3">
      <h3 className="text-sm font-bold">届いているスカウト</h3>
      {rows}
      {message && <p className="text-sm text-destructive">{message}</p>}
    </section>
  );
}

type MessageFormProps = {
  // 今送れるか（Rails の can_send）。false なら入力欄とボタンを使えなくする（判定は Rails。16-1-9）
  canSend: boolean;
  // ㊳㊶ 送信の窓口
  sendPath: string;
  cannotSendMessage: string;
  onSent: (message: Message) => void;
  onConflict: () => void;
};

// 本文の入力欄と「送信する」。守りは Rails にある（送れなければ 409、本文が空・長すぎるなら 422）。
// 画面側の確かめは、送る手間を省くためだけ
function MessageForm({ canSend, sendPath, cannotSendMessage, onSent, onConflict }: MessageFormProps) {
  const redirectIfUnauthorized = useRedirectIfUnauthorized();
  // 入力中の本文
  const [body, setBody] = useState("");
  // 本文の欄の下に出すエラー
  const [errors, setErrors] = useState<string[] | undefined>(undefined);
  // 入力の誤り以外で送れなかったときの一言
  const [notice, setNotice] = useState<string | null>(null);
  // 送っている途中か。2回押しても、1回だけ送る
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    // ブラウザの標準の送信（画面の読み込み直し）を止め、JavaScript で送る
    event.preventDefault();
    if (submitting || !canSend) return;

    // ① 空（空白だけも含む。Rails も空として扱う）なら、送らずにエラーを出す
    if (body.trim() === "") {
      setErrors([BODY_REQUIRED_MESSAGE]);
      return;
    }
    setErrors(undefined);
    setNotice(null);
    setSubmitting(true);

    try {
      // ② 送る（㊳㊶）。返事は作ったメッセージ1件
      const message = await apiFetch<Message>(sendPath, { method: "POST", body: { body } });
      setBody("");
      onSent(message);
    } catch (error) {
      if (redirectIfUnauthorized(error)) return;
      // ③ 入力の誤り（422。2,000文字を超えた、など）なら、本文の欄の下に出す
      if (error instanceof ApiError && error.status === 422 && error.errors) {
        setErrors(error.errors.body ?? [error.message]);
        return;
      }
      // それ以外は一言を出す。409 なら、送れるかを含めて取り直す
      setNotice(error instanceof ApiError ? error.message : FALLBACK_ERROR_MESSAGE);
      if (error instanceof ApiError && error.status === 409) onConflict();
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-2 border-t pt-4">
      {notice && <p className="text-sm text-destructive">{notice}</p>}
      <Field data-invalid={errors ? true : undefined}>
        <FieldLabel htmlFor="message-body" className="sr-only">
          メッセージ
        </FieldLabel>
        <Textarea
          id="message-body"
          rows={3}
          value={body}
          disabled={!canSend}
          onChange={(event) => setBody(event.target.value)}
          aria-invalid={errors ? true : undefined}
        />
        <FieldDescription>
          {canSend ? `${body.length}／${LONG_TEXT_MAX_LENGTH}文字` : cannotSendMessage}
        </FieldDescription>
        <FieldError errors={toFieldErrorItems(errors)} />
      </Field>
      <div className="flex justify-end">
        <Button type="submit" disabled={!canSend}>
          {submitting ? "送信中…" : "送信する"}
        </Button>
      </div>
    </form>
  );
}
