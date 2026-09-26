// やりとりの状態などを出す小さな札（「応募済み」「未対応応募」など）。
// 募集詳細・募集管理（学生）と候補者一覧（企業）で使い回し、見た目をそろえる。
// 文字は、Rails が返した値を ⑦ の選択肢で日本語にしたものを渡す（画面側では組み立てない。API設計.md の 16-1-9）

import { cn } from "cn";

type StatusBadgeProps = {
  children: string;
  // 大きさ。行の中に並べるときは "sm"
  size?: "sm" | "md";
  className?: string;
};

export function StatusBadge({ children, size = "md", className }: StatusBadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex rounded-md bg-secondary font-medium",
        size === "sm" ? "px-2 py-0.5 text-xs" : "px-2 py-1 text-sm",
        className,
      )}
    >
      {children}
    </span>
  );
}
