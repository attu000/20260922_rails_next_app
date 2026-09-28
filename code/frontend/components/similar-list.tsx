// 似たもののポップアップの一覧の枠（順14）。
// スカウト送信後の「この学生に似た学生」と、応募完了の「この募集に似た募集」で使い回す。
// 5件並べると縦に長くなるので、この枠の中だけを縦にスクロールできるようにする（PR319）

import type { ReactNode } from "react";

type SimilarListProps = {
  loading: boolean;
  // 取れなかったときの一言。なければ null
  errorMessage: string | null;
  // 小見出し（「この学生に似た学生」「この募集に似た募集」）
  heading: string;
  count: number;
  // 行（<li>）の並び
  children: ReactNode;
  // 行の中のリンク（名前・募集名・「詳細を見る」）が押されたとき。ポップアップを閉じるのに使う
  onLinkClick: () => void;
};

export function SimilarList({ loading, errorMessage, heading, count, children, onLinkClick }: SimilarListProps) {
  if (loading) return <p className="text-sm text-muted-foreground">読み込み中…</p>;
  if (errorMessage) return <p className="text-sm text-destructive">{errorMessage}</p>;
  // 0件なら、小見出しも一覧も出さない（題名と「閉じる」だけ。PR320）
  if (count === 0) return null;

  return (
    <section className="space-y-3">
      <h3 className="text-sm font-bold">{heading}</h3>
      {/* 行のリンクで別の学生・募集の画面へ移るとき、ポップアップを閉じる（開いたまま次の画面に残さない）。
          リンクそのものの移動が先に動き、そのあとここに伝わってくる */}
      <ul
        className="max-h-[60vh] space-y-3 overflow-y-auto"
        onClick={(event) => {
          if (event.target instanceof Element && event.target.closest("a")) onLinkClick();
        }}
      >
        {children}
      </ul>
    </section>
  );
}
