// 「メイン｜サブ」を切り替える、小さなボタン2つ。選んでいるほうを濃くする。
// 募集詳細編集の職種（メイン｜サブ）と工程（メイン｜関われる。PR236）で、チェックを入れた行の横に出す。
// 読み上げ（スクリーンリーダー）には、「2つのうち1つを選ぶ」もの（ラジオボタンと同じ）として伝える

import { cn } from "@/lib/utils";
import type { Role } from "@/lib/role-ids";

type RoleToggleProps = {
  // 読み上げ用の名前（例：「フロントエンドの区分」）
  label: string;
  // 選択肢（例：[{ value: "main", label: "メイン" }, { value: "sub", label: "サブ" }]）
  choices: { value: Role; label: string }[];
  value: Role;
  onChange: (role: Role) => void;
};

export function RoleToggle({ label, choices, value, onChange }: RoleToggleProps) {
  return (
    <div role="radiogroup" aria-label={label} className="inline-flex shrink-0 rounded-md border p-0.5">
      {choices.map((choice) => {
        const selected = choice.value === value;
        return (
          <button
            key={choice.value}
            // フォームの中にあるので、押しても保存が走らないよう type="button" を付ける
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => onChange(choice.value)}
            className={cn(
              "rounded px-2 py-0.5 text-xs whitespace-nowrap transition-colors",
              selected ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-muted",
            )}
          >
            {choice.label}
          </button>
        );
      })}
    </div>
  );
}
