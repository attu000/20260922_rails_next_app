// Markdown の文を表示する部品（PR396）。プチ職業体験の講座の解説・問題の文で使う（API設計.md の 16-3-9。PR382）。
// Django のテンプレートでいう {{ text|markdown }} にあたる。
// react-markdown は、文の中に HTML が書かれていても HTML として出さない（標準の動き）。
// 見た目は、講座の YAML で使っている書き方（段落・箇条書き・引用・太字）にだけ当てる

import Markdown from "react-markdown";
import { cn } from "cn";

export function MarkdownText({ children, className }: { children: string; className?: string }) {
  return (
    <div
      className={cn(
        "space-y-3 text-sm leading-relaxed",
        // 箇条書き（「- 」）と番号付きの箇条書き（「1. 」）
        "[&_ol]:list-decimal [&_ol]:space-y-1 [&_ol]:pl-5 [&_ul]:list-disc [&_ul]:space-y-1 [&_ul]:pl-5",
        // 引用（「> 」）。題材の仕様や、テストケースの例に使っている
        "[&_blockquote]:space-y-2 [&_blockquote]:border-l-4 [&_blockquote]:pl-3 [&_blockquote]:text-muted-foreground",
        // 太字（「**…**」）
        "[&_strong]:font-bold",
        className,
      )}
    >
      <Markdown>{children}</Markdown>
    </div>
  );
}
