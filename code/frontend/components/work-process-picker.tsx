// 募集の工程を選ぶ入力欄（design/designs/ページ設計.md の 6-5 C3、その他決め事.md の 5-8）。
// 13個をマスタの表示順（上流 → 下流）のまま1列に並べ、選んでも並びは動かさない（PR241。押そうとした場所がずれないように）。
// チェックを入れた行の横で「メイン｜関われる」を切り替える（PR235・PR236）。チェックを入れた時点ではメイン（lib/role-ids.ts）

import { toFieldErrorItems } from "@/components/form-fields";
import { RoleToggle } from "@/components/role-toggle";
import { Checkbox } from "@/components/ui/checkbox";
import { Field, FieldError, FieldLabel, FieldLegend, FieldSet } from "@/components/ui/field";
import type { WorkProcess } from "@/lib/options";
import { roleOf, selectedIdsOf, withRole, withSelectedIds, type Role, type RoleIds } from "@/lib/role-ids";

// メイン／関われるの切り替えの選択肢（PR236）
const WORK_PROCESS_ROLES: { value: Role; label: string }[] = [
  { value: "main", label: "メイン" },
  { value: "sub", label: "関われる" },
];

type WorkProcessPickerProps = {
  // 工程のマスタ（表示順。⑦ の masters.work_processes）
  workProcesses: WorkProcess[];
  // メイン（メインで担当する工程）と、サブ（関われる工程）の番号の一覧
  value: RoleIds;
  onChange: (value: RoleIds) => void;
  // Rails のエラー（メインで担当する工程・関われる工程のどちらのものも、まとめて渡す）
  errors?: string[];
};

export function WorkProcessPicker({ workProcesses, value, onChange, errors }: WorkProcessPickerProps) {
  const selectedIds = selectedIdsOf(value);

  function toggle(id: number, checked: boolean) {
    const nextIds = checked ? [...selectedIds, id] : selectedIds.filter((selectedId) => selectedId !== id);
    onChange(withSelectedIds(value, nextIds));
  }

  return (
    <FieldSet>
      {/* まとまりの見出しに「工程」と出ているので、見出しは読み上げにだけ残す */}
      <FieldLegend className="sr-only">工程</FieldLegend>
      <div className="grid gap-2">
        {workProcesses.map((workProcess) => {
          const id = `work-process-${workProcess.id}`;
          const checked = selectedIds.includes(workProcess.id);
          return (
            <div key={workProcess.id} className="flex min-h-7 items-center gap-2">
              <Field orientation="horizontal" className="flex-1">
                <Checkbox
                  id={id}
                  checked={checked}
                  onCheckedChange={(nextChecked) => toggle(workProcess.id, nextChecked)}
                  aria-invalid={errors ? true : undefined}
                />
                <FieldLabel htmlFor={id} className="font-normal">
                  {workProcess.name}
                </FieldLabel>
              </Field>
              {checked && (
                <RoleToggle
                  label={`${workProcess.name}の区分`}
                  choices={WORK_PROCESS_ROLES}
                  value={roleOf(value, workProcess.id)}
                  onChange={(role) => onChange(withRole(value, workProcess.id, role))}
                />
              )}
            </div>
          );
        })}
      </div>
      <FieldError errors={toFieldErrorItems(errors)} />
    </FieldSet>
  );
}
