import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// ブラウザのタブに出るタイトル。サービス名は仮の名前（正式な名前を決めたら、ここ1か所を直す）。
// 画面ごとのタイトルは「ログイン（企業用） | ハロー・インターン」のように出る
export const metadata: Metadata = {
  title: {
    default: "ハロー・インターン",
    template: "%s | ハロー・インターン",
  },
  description: "エンジニア職の長期インターンを探す学生と、学生を探す企業をつなぐ、募集・スカウトサービス（プロトタイプ）",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  // lang="ja"：日本語の画面だと、ブラウザや読み上げの道具に伝える
  return (
    <html
      lang="ja"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
