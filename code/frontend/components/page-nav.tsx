// ページ送り（「前へ 1 … 4 5 6 … 10 次へ」）。ページ分けする一覧で使い回す（design/designs/API設計.md の 16-1-11）。
// 番号は Next.js の Link で、押すと URL の ?page= が変わる。どの URL にするかは、使う側が hrefFor で決める
// （検索の条件など、ほかのクエリを残したままページだけを変えるため）

import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";

type PageNavProps = {
  // 今のページ（1から）
  page: number;
  totalPages: number;
  // そのページの URL を作る関数
  hrefFor: (page: number) => string;
};

// 出す番号：最初・最後・今のページの前後1つ。間が飛ぶところは null（「…」を出す）。
// 例：全10ページで5ページ目 → [1, null, 4, 5, 6, null, 10]
function pageItems(page: number, totalPages: number): (number | null)[] {
  const shown = [1, page - 1, page, page + 1, totalPages].filter((n) => n >= 1 && n <= totalPages);
  const unique = [...new Set(shown)].sort((a, b) => a - b);

  const items: (number | null)[] = [];
  unique.forEach((n, index) => {
    if (index > 0 && n - unique[index - 1] > 1) items.push(null);
    items.push(n);
  });
  return items;
}

export function PageNav({ page, totalPages, hrefFor }: PageNavProps) {
  // 1ページしかなければ出さない
  if (totalPages <= 1) return null;

  const linkClass = buttonVariants({ variant: "outline", size: "sm" });

  return (
    <nav aria-label="ページ送り" className="flex flex-wrap items-center justify-center gap-1">
      {page > 1 && (
        <Link href={hrefFor(page - 1)} className={linkClass}>
          前へ
        </Link>
      )}
      {pageItems(page, totalPages).map((n, index) =>
        n === null ? (
          <span key={`gap-${index}`} className="px-1 text-sm text-muted-foreground">
            …
          </span>
        ) : n === page ? (
          // 今のページは押せない見た目にする
          <span key={n} aria-current="page" className={buttonVariants({ variant: "default", size: "sm" })}>
            {n}
          </span>
        ) : (
          <Link key={n} href={hrefFor(n)} className={linkClass}>
            {n}
          </Link>
        ),
      )}
      {page < totalPages && (
        <Link href={hrefFor(page + 1)} className={linkClass}>
          次へ
        </Link>
      )}
    </nav>
  );
}
