// 丸いアイコン。企業・学生のアイコンを出すすべての場所で使う（design/designs/ページ設計.md の 6-4）。
// 画像がない（null）か読み込めなければ、名前の頭文字を出す（API設計.md の 16-3 形A「画面側で既定の画像を出す」）

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";

type ProfileIconProps = {
  // アイコンの URL。未登録なら null
  src: string | null;
  // 会社名・氏名。頭文字に使う
  name: string | null;
  size?: "default" | "sm" | "lg";
  className?: string;
};

export function ProfileIcon({ src, name, size = "default", className }: ProfileIconProps) {
  return (
    <Avatar size={size} className={className}>
      {src && <AvatarImage src={src} alt="" />}
      {/* 「株式会社サンプル」なら「株」 */}
      <AvatarFallback>{name?.charAt(0) ?? ""}</AvatarFallback>
    </Avatar>
  );
}
