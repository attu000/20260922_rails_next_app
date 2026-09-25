// プログラミング歴の入力欄。行を足す・消す形で、1行に「技術（なければ「その他」と名前）・年数・レベル」を持つ。
// 詳しくは design/designs/ページ設計.md の 6-6 S1、API設計.md の 16-3 ⑯。
// Django でいえば、同じ形のフォームを行数ぶん並べるフォームセットを、画面側だけで組み立てるのにあたる。
// 行の値の変換（Rails の形 ⇔ フォームの形）と、その場での確認もここに置く

import { toFieldErrorItems, SHORT_TEXT_MAX_LENGTH, type FieldErrors } from "@/components/form-fields";
import { Button } from "@/components/ui/button";
import { FieldDescription, FieldError, FieldLegend, FieldSet } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { NativeSelect, NativeSelectOptGroup, NativeSelectOption } from "@/components/ui/native-select";
import type { EnumOption, TechnologyRow } from "@/lib/options";
import type { StudentSkill } from "@/lib/student-profile";

// 行数と年数の上限。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）
export const SKILLS_MAX = 50;
const YEARS_MAX = 50;

// 技術の選択欄で「その他」を表す値
const OTHER = "other";

// フォームが持つ1行の値。入力欄にそのまま入れるため、すべて文字で持つ
export type SkillRow = {
  // React が行を見分ける印。消したときに、ほかの行の入力が入れ替わらないようにするため
  key: string;
  // "" 未選択 ／ "12" 技術の番号 ／ "other" その他
  technology: string;
  other_name: string;
  years: string;
  // "" 未選択 ／ "v1"〜"v4"
  level: string;
};

// 行の印の通し番号（画面を開いている間だけ使う）
let nextRowKey = 0;

function newRowKey(): string {
  nextRowKey += 1;
  return `skill-${nextRowKey}`;
}

// 空の1行（「行を足す」で使う）。レベルは本人に選んでもらうため空にする
export function newSkillRow(): SkillRow {
  return { key: newRowKey(), technology: "", other_name: "", years: "", level: "" };
}

// Rails の返事 → フォームの行。技術が null の行は「その他」
export function toSkillRows(skills: StudentSkill[]): SkillRow[] {
  return skills.map((skill) => ({
    key: newRowKey(),
    technology: skill.technology_id === null ? OTHER : String(skill.technology_id),
    other_name: skill.other_name ?? "",
    years: skill.years === null ? "" : String(skill.years),
    level: skill.level,
  }));
}

// フォームの行 → Rails に送る形。「その他」なら技術は null で名前を送り、技術を選んだなら名前は null にする
export function toSkillRequest(rows: SkillRow[]) {
  return rows.map((row) => ({
    technology_id: row.technology === "" || row.technology === OTHER ? null : Number(row.technology),
    other_name: row.technology === OTHER ? row.other_name : null,
    years: row.years.trim() === "" ? null : Number(row.years),
    level: row.level === "" ? null : row.level,
  }));
}

// その場での確認（権限_バリデーション.md の 17-3-2）。Rails と同じ文言・同じ名前（skills[0].years など）で返す。
// Rails も同じ確認をするので、ここをすり抜けても守られる
export function validateSkillRows(rows: SkillRow[]): FieldErrors {
  const errors: FieldErrors = {};
  rows.forEach((row, index) => {
    const name = (attribute: string) => `skills[${index}].${attribute}`;

    if (row.technology === "" || (row.technology === OTHER && row.other_name.trim() === "")) {
      errors[name("technology_id")] = ["技術を入力してください"];
    }
    if (row.technology === OTHER && row.other_name.length > SHORT_TEXT_MAX_LENGTH) {
      errors[name("other_name")] = [`その他の名前は${SHORT_TEXT_MAX_LENGTH}文字以内で入力してください`];
    }

    // 年数は任意。入っていれば 0〜50 の、0.5刻みの数
    if (row.years.trim() !== "") {
      const years = Number(row.years);
      if (Number.isNaN(years)) {
        errors[name("years")] = ["年数は数値で入力してください"];
      } else if (years < 0) {
        errors[name("years")] = ["年数は0以上の値にしてください"];
      } else if (years > YEARS_MAX) {
        errors[name("years")] = [`年数は${YEARS_MAX}以下の値にしてください`];
      } else if (!Number.isInteger(years * 2)) {
        errors[name("years")] = ["年数は0.5刻みで入力してください"];
      }
    }

    if (row.level === "") {
      errors[name("level")] = ["レベルを入力してください"];
    }
  });
  return errors;
}

// 1行分のエラー（技術・名前・年数・レベル）を、まとめて行の下に出すために集める
function rowErrors(errors: FieldErrors, index: number) {
  const pick = (attribute: string) => errors[`skills[${index}].${attribute}`];
  return {
    technology: pick("technology_id"),
    otherName: pick("other_name"),
    years: pick("years"),
    level: pick("level"),
  };
}

type SkillRowsFieldProps = {
  rows: SkillRow[];
  // 技術のマスタと区分（区分ごとに見出しを付けて並べる）、レベルの選択肢。どれも ⑦ の値をそのまま使う
  technologies: TechnologyRow[];
  categories: EnumOption[];
  levels: EnumOption[];
  // フォーム全体のエラー。skills[0].years などの行のエラーと、skills（欄全体）のエラーを拾って出す
  errors: FieldErrors;
  onChange: (rows: SkillRow[]) => void;
};

// 部品は、フォームの中ではなくファイルの一番上の段に置く（打っている途中でカーソルが外れないように）
export function SkillRowsField({ rows, technologies, categories, levels, errors, onChange }: SkillRowsFieldProps) {
  function updateRow(index: number, changes: Partial<SkillRow>) {
    onChange(rows.map((row, rowIndex) => (rowIndex === index ? { ...row, ...changes } : row)));
  }

  function removeRow(index: number) {
    onChange(rows.filter((_, rowIndex) => rowIndex !== index));
  }

  return (
    <FieldSet>
      <FieldLegend variant="label">プログラミング歴</FieldLegend>
      <FieldDescription>
        言語・フレームワークなど。一覧にないものは「その他」を選んで、名前を入力してください
      </FieldDescription>

      {rows.length > 0 && (
        <ul className="space-y-2">
          {rows.map((row, index) => {
            const messages = rowErrors(errors, index);
            const allMessages = [messages.technology, messages.otherName, messages.years, messages.level]
              .flatMap((list) => list ?? []);
            // ほかの行で選んだ技術は選べなくする（同じ技術を2行にしないため）
            const takenIds = new Set(
              rows.filter((_, rowIndex) => rowIndex !== index).map((other) => other.technology),
            );
            return (
              <li key={row.key} className="rounded-lg border p-3">
                <div className="flex flex-wrap items-center gap-2">
                  <NativeSelect
                    aria-label={`${index + 1}行目の技術`}
                    value={row.technology}
                    onChange={(event) => updateRow(index, { technology: event.target.value })}
                    aria-invalid={messages.technology ? true : undefined}
                    className="w-48"
                  >
                    <NativeSelectOption value="">技術を選択</NativeSelectOption>
                    {categories.map((category) => (
                      <NativeSelectOptGroup key={category.value} label={category.label}>
                        {technologies
                          .filter((technology) => technology.category === category.value)
                          .map((technology) => (
                            <NativeSelectOption
                              key={technology.id}
                              value={String(technology.id)}
                              disabled={takenIds.has(String(technology.id))}
                            >
                              {technology.name}
                            </NativeSelectOption>
                          ))}
                      </NativeSelectOptGroup>
                    ))}
                    <NativeSelectOption value={OTHER}>その他（一覧にない）</NativeSelectOption>
                  </NativeSelect>

                  {row.technology === OTHER && (
                    <Input
                      aria-label={`${index + 1}行目のその他の名前`}
                      placeholder="技術の名前"
                      value={row.other_name}
                      onChange={(event) => updateRow(index, { other_name: event.target.value })}
                      aria-invalid={messages.technology || messages.otherName ? true : undefined}
                      className="w-40"
                    />
                  )}

                  <div className="flex items-center gap-1">
                    <Input
                      aria-label={`${index + 1}行目の年数`}
                      inputMode="decimal"
                      placeholder="年数"
                      value={row.years}
                      onChange={(event) => updateRow(index, { years: event.target.value })}
                      aria-invalid={messages.years ? true : undefined}
                      className="w-20"
                    />
                    <span className="text-sm">年</span>
                  </div>

                  <NativeSelect
                    aria-label={`${index + 1}行目のレベル`}
                    value={row.level}
                    onChange={(event) => updateRow(index, { level: event.target.value })}
                    aria-invalid={messages.level ? true : undefined}
                    className="w-64"
                  >
                    <NativeSelectOption value="">レベルを選択</NativeSelectOption>
                    {levels.map((level) => (
                      <NativeSelectOption key={level.value} value={level.value}>
                        {level.label}
                      </NativeSelectOption>
                    ))}
                  </NativeSelect>

                  <Button type="button" variant="ghost" size="sm" onClick={() => removeRow(index)}>
                    削除
                  </Button>
                </div>
                {/* この行のエラーは、この行の下にまとめて出す（API設計.md の 16-3 ⑯） */}
                <FieldError errors={toFieldErrorItems(allMessages.length > 0 ? allMessages : undefined)} />
              </li>
            );
          })}
        </ul>
      )}

      {/* 50行になったら、足すボタンを出さない */}
      {rows.length < SKILLS_MAX && (
        <div>
          <Button type="button" variant="outline" size="sm" onClick={() => onChange([...rows, newSkillRow()])}>
            ＋ 行を足す
          </Button>
        </div>
      )}

      {/* 欄全体のエラー（同じ技術が2行、51行以上など） */}
      <FieldError errors={toFieldErrorItems(errors.skills)} />
    </FieldSet>
  );
}
