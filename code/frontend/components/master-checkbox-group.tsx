// マスタ（業界、事業形態など）の行を、チェックボックスの一覧として並べる。複数選択の入力欄で使い回す。
// 選ばれている番号の一覧は、使う側（フォーム）が持つ

import { Checkbox } from "@/components/ui/checkbox";
import { Field, FieldError, FieldLabel, FieldLegend, FieldSet } from "@/components/ui/field";
import type { MasterRow } from "@/lib/options";

type MasterCheckboxGroupProps = {
  // 入力欄の名前。チェックボックスの id を作るのに使う（例："industry"）
  name: string;
  legend: string;
  rows: MasterRow[];
  selectedIds: number[];
  onChange: (selectedIds: number[]) => void;
  // Rails や画面側の確認で見つかったエラー（例：「業界に選べない値が含まれています」）
  errors?: string[];
};

export function MasterCheckboxGroup({ name, legend, rows, selectedIds, onChange, errors }: MasterCheckboxGroupProps) {
  function toggle(id: number, checked: boolean) {
    onChange(checked ? [...selectedIds, id] : selectedIds.filter((selectedId) => selectedId !== id));
  }

  return (
    <FieldSet>
      <FieldLegend variant="label">{legend}</FieldLegend>
      <div className="grid gap-2 sm:grid-cols-2">
        {rows.map((row) => {
          const id = `${name}-${row.id}`;
          return (
            <Field key={row.id} orientation="horizontal">
              <Checkbox
                id={id}
                checked={selectedIds.includes(row.id)}
                onCheckedChange={(checked) => toggle(row.id, checked)}
                aria-invalid={errors ? true : undefined}
              />
              <FieldLabel htmlFor={id} className="font-normal">
                {row.name}
              </FieldLabel>
            </Field>
          );
        })}
      </div>
      <FieldError errors={errors?.map((message) => ({ message }))} />
    </FieldSet>
  );
}
