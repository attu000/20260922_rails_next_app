// 資格の入力欄。行を足す・消す形で、1行に資格名を1つ持つ（プログラミング歴の部品と同じ作り）。
// 詳しくは design/designs/ページ設計.md の 6-6 S1、API設計.md の 16-3 ⑥⑯。順17。
// Rails とは資格名の文字の配列（["基本情報技術者", …]）でやりとりする

import { SHORT_TEXT_MAX_LENGTH, toFieldErrorItems, type FieldErrors } from "@/components/form-fields";
import { Button } from "@/components/ui/button";
import { FieldError, FieldLegend, FieldSet } from "@/components/ui/field";
import { Input } from "@/components/ui/input";

// 行数の上限。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）
export const CERTIFICATIONS_MAX = 50;

// フォームが持つ1行の値
export type CertificationRow = {
  // React が行を見分ける印。消したときに、ほかの行の入力が入れ替わらないようにするため
  key: string;
  name: string;
};

// 行の印の通し番号（画面を開いている間だけ使う）
let nextRowKey = 0;

function newRowKey(): string {
  nextRowKey += 1;
  return `certification-${nextRowKey}`;
}

// Rails の返事（資格名の配列）→ フォームの行
export function toCertificationRows(names: string[]): CertificationRow[] {
  return names.map((name) => ({ key: newRowKey(), name }));
}

// フォームの行 → Rails に送る形（資格名の配列）
export function toCertificationRequest(rows: CertificationRow[]): string[] {
  return rows.map((row) => row.name);
}

// その場での確認（権限_バリデーション.md の 17-3-2）。Rails と同じ文言・同じ名前（certifications[0].name）で返す
export function validateCertificationRows(rows: CertificationRow[]): FieldErrors {
  const errors: FieldErrors = {};
  rows.forEach((row, index) => {
    if (row.name.trim() === "") {
      errors[`certifications[${index}].name`] = ["資格名を入力してください"];
    } else if (row.name.length > SHORT_TEXT_MAX_LENGTH) {
      errors[`certifications[${index}].name`] = [`資格名は${SHORT_TEXT_MAX_LENGTH}文字以内で入力してください`];
    }
  });
  return errors;
}

type CertificationRowsFieldProps = {
  rows: CertificationRow[];
  // フォーム全体のエラー。certifications[0].name などの行のエラーと、certifications（欄全体）のエラーを拾って出す
  errors: FieldErrors;
  onChange: (rows: CertificationRow[]) => void;
};

// 部品は、フォームの中ではなくファイルの一番上の段に置く（打っている途中でカーソルが外れないように）
export function CertificationRowsField({ rows, errors, onChange }: CertificationRowsFieldProps) {
  return (
    <FieldSet>
      <FieldLegend variant="label">資格</FieldLegend>

      {rows.length > 0 && (
        <ul className="space-y-2">
          {rows.map((row, index) => {
            const nameErrors = errors[`certifications[${index}].name`];
            return (
              <li key={row.key} className="rounded-lg border p-3">
                <div className="flex flex-wrap items-center gap-2">
                  <Input
                    aria-label={`${index + 1}行目の資格名`}
                    placeholder="資格名（例：基本情報技術者）"
                    value={row.name}
                    onChange={(event) =>
                      onChange(rows.map((other, rowIndex) => (rowIndex === index ? { ...other, name: event.target.value } : other)))
                    }
                    aria-invalid={nameErrors ? true : undefined}
                    className="w-72 max-w-full"
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => onChange(rows.filter((_, rowIndex) => rowIndex !== index))}
                  >
                    削除
                  </Button>
                </div>
                <FieldError errors={toFieldErrorItems(nameErrors)} />
              </li>
            );
          })}
        </ul>
      )}

      {/* 50行になったら、足すボタンを出さない */}
      {rows.length < CERTIFICATIONS_MAX && (
        <div>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => onChange([...rows, { key: newRowKey(), name: "" }])}
          >
            ＋ 資格を足す
          </Button>
        </div>
      )}

      {/* 欄全体のエラー（51件以上） */}
      <FieldError errors={toFieldErrorItems(errors.certifications)} />
    </FieldSet>
  );
}
