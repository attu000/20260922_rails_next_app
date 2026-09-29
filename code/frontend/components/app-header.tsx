"use client";

// ログイン後の画面のヘッダー。企業用・学生用で共通（design/designs/ページ設計.md の 6-2、API設計.md の 16-2-1）。
// 見た目は、shadcn/ui の部品と標準の色で、最低限だけそろえている（細かい見た目は後回し）

import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { apiFetch } from "@/lib/api";
import { loginPathFor, type Role } from "@/lib/auth";
import { useMe } from "@/components/member-only";
import { ProfileIcon } from "@/components/profile-icon";

// タブ。行き先の画面はすべてある（メッセージは順7、通知は順15、プチ職業体験は順18 で作った。未決内容.md の 11-2）。
// 学生のプチ職業体験は、「体験してから応募する」使い方が伝わるよう、募集検索の次に置く（ページ設計.md の 6-2。PR385）
const TABS: Record<Role, { label: string; href: string }[]> = {
  company: [
    { label: "会社情報", href: "/company/profile" },
    { label: "募集管理", href: "/company/job_postings" },
    { label: "候補者管理", href: "/company/candidacies" },
    { label: "学生検索", href: "/company/students" },
    { label: "メッセージ", href: "/company/messages" },
  ],
  student: [
    { label: "マイページ", href: "/student/profile" },
    { label: "募集検索", href: "/student/job_postings" },
    { label: "プチ職業体験", href: "/student/job_trials" },
    { label: "募集管理", href: "/student/candidacies" },
    { label: "スカウト管理", href: "/student/scouts" },
    { label: "メッセージ", href: "/student/messages" },
  ],
};

// 未読件数の表示。1〜9 はそのまま、10以上は「9+」。0 と null（学生）は何も付けない
function formatUnreadCount(count: number | null): string {
  if (!count) return "";
  return `（${count > 9 ? "9+" : count}）`;
}

export function AppHeader() {
  const me = useMe();
  const router = useRouter();

  async function handleLogout() {
    // ② DELETE /api/session。失敗しても（通信の失敗など）ログイン画面へ移す。
    // ログインが残っていれば、ログイン画面の枠（GuestOnly）がホームへ戻すので、利用者が迷うことはない
    await apiFetch<null>("/api/session", { method: "DELETE" }).catch(() => null);
    router.replace(loginPathFor(me.role));
  }

  return (
    <header className="border-b">
      {/* 中身の幅と余白は、本文（ログイン後の枠の main）とそろえている */}
      <div className="mx-auto flex max-w-5xl flex-wrap items-center gap-4 px-4 py-3 text-sm">
        <nav className="flex flex-wrap gap-4">
          {TABS[me.role].map((tab) => (
            <Link key={tab.href} href={tab.href} className="hover:underline">
              {tab.label}
            </Link>
          ))}
          {/* 通知は企業だけ。ベルの絵ではなく文字にしている（見た目は最小限）。
              未読があれば件数を付ける（10件以上は「9+」。ページ設計.md の 6-5 C10）。件数は画面を移るたびに取り直す */}
          {me.role === "company" && (
            <Link href="/company/notifications" className="hover:underline">
              通知{formatUnreadCount(me.unread_notifications_count)}
            </Link>
          )}
        </nav>

        <div className="ml-auto flex items-center gap-4">
          {/* 企業なら会社名、学生なら氏名。アイコンがなければ頭文字（学生のアイコンは順3 で作るので、それまでは頭文字） */}
          <div className="flex items-center gap-2">
            <ProfileIcon src={me.icon_url} name={me.name} size="sm" />
            <span>{me.name}</span>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={handleLogout}>
            ログアウト
          </Button>
        </div>
      </div>
    </header>
  );
}
