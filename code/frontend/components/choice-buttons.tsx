// 1つだけ選ぶボタンの並び（「指定なし」「週1日まで」「週2日まで」…）。選んでいるボタンは色を変える。
// 募集一覧（学生のホーム）と学生検索（企業）の条件のポップアップで使う。
// 押すと、使う側の値が変わるだけ（検索は「検索する」を押したときだけ。PR192）

import { buttonVariants } from "@/components/ui/button";
import { FieldLegend, FieldSet } from "@/components/ui/field";

// T は値の型。数（週の日数など）か、文字（勤務形態 "full_remote"、レベル "v2" など）
type ChoiceButtonsProps<T extends number | string> = {
  legend: string;
  // 選択肢。value は値（例：3）、label は画面に出す言葉（例：「週3日まで」）
  choices: { value: T; label: string }[];
  // 選んでいる値。null は「指定なし」
  value: T | null;
  onChange: (value: T | null) => void;
};

export function ChoiceButtons<T extends number | string>({ legend, choices, value, onChange }: ChoiceButtonsProps<T>) {
  // 「指定なし」を先頭に置く
  const items: { value: T | null; label: string }[] = [{ value: null, label: "指定なし" }, ...choices];

  return (
    <FieldSet>
      <FieldLegend variant="label">{legend}</FieldLegend>
      <div className="flex flex-wrap gap-2">
        {items.map((item) => {
          const selected = item.value === value;
          return (
            <button
              key={item.label}
              // 条件欄の form の中にあるので、押しても検索が走らないよう type="button" を付ける
              type="button"
              // 読み上げ（スクリーンリーダー）に、押されている状態を伝える
              aria-pressed={selected}
              onClick={() => onChange(item.value)}
              className={buttonVariants({ variant: selected ? "default" : "outline", size: "sm" })}
            >
              {item.label}
            </button>
          );
        })}
      </div>
    </FieldSet>
  );
}
