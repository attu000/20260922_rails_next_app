// 職種を「大分類 → 中分類」の2段階で選ぶ入力欄（design/designs/ページ設計.md の 6-5 C3、その他決め事.md の 5-7）。
// 大分類は常に表示し、チェックを入れた大分類の下に、中分類が開く。開いた中分類は「⌄」のボタンで閉じられる（選んだものは残る）。
// 募集詳細編集の「主な職種」「関連する職種」と、マイページの「興味のある職種」、募集一覧（学生のホーム）の検索の条件で使い回す
// （マイページと募集一覧では選べない中分類はない）。
// 選ばれている中分類の番号の一覧は、使う側（フォーム）が持つ。大分類のチェックと開閉は、この部品の中だけで覚える（保存しない）。
// 募集一覧では「大分類だけ選んだ」ことも条件になるので、大分類のチェックを外に知らせる（onCheckedMajorsChange）

import { useState } from "react";
import { ChevronDownIcon } from "lucide-react";
import { buttonVariants } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { Field, FieldContent, FieldDescription, FieldError, FieldLabel, FieldLegend, FieldSet } from "@/components/ui/field";
import type { JobMajorCategory } from "@/lib/options";

type JobCategoryPickerProps = {
  // 入力欄の名前。チェックボックスの id を作るのに使う（例："main-job-category"）
  name: string;
  legend: string;
  majors: JobMajorCategory[];
  selectedIds: number[];
  // もう一方（主な職種・関連する職種）で選んでいる中分類。同じ中分類は両方には入れられない
  disabledIds: number[];
  // 選べない中分類に添える一言（例：「関連する職種で選択済み」）
  disabledNote: string;
  onChange: (selectedIds: number[]) => void;
  // Rails や画面側の確認で見つかったエラー
  errors?: string[];
  // 最初にチェックを入れておく大分類（募集一覧で、URL の job_major_category_ids から）。
  // 省略時は、選んでいる中分類を含む大分類だけにチェックを入れる
  initialCheckedMajorIds?: number[];
  // 大分類のチェックが変わったら知らせる（募集一覧で使う）
  onCheckedMajorsChange?: (majorIds: number[]) => void;
};

export function JobCategoryPicker({
  name,
  legend,
  majors,
  selectedIds,
  disabledIds,
  disabledNote,
  onChange,
  errors,
  initialCheckedMajorIds = [],
  onCheckedMajorsChange,
}: JobCategoryPickerProps) {
  // チェックを入れている大分類。最初は、選んでいる中分類を含む大分類にチェックを入れておく（編集のとき、選んだものが見えるように）。
  // 募集一覧では、URL で大分類だけ選んでいたものにもチェックを入れる
  const [checkedMajorIds, setCheckedMajorIds] = useState<number[]>(() =>
    majors
      .filter(
        (major) =>
          initialCheckedMajorIds.includes(major.id) ||
          major.job_middle_categories.some((middle) => selectedIds.includes(middle.id)),
      )
      .map((major) => major.id),
  );
  // チェックは入っているが、「⌄」のボタンで中分類を閉じている大分類
  const [collapsedMajorIds, setCollapsedMajorIds] = useState<number[]>([]);

  // 大分類のチェックを変え、使う側にも知らせる
  function updateCheckedMajorIds(nextIds: number[]) {
    setCheckedMajorIds(nextIds);
    onCheckedMajorsChange?.(nextIds);
  }

  function toggleMajor(major: JobMajorCategory, checked: boolean) {
    if (checked) {
      // チェックを入れたら、中分類を開く
      updateCheckedMajorIds([...checkedMajorIds, major.id]);
      setCollapsedMajorIds(collapsedMajorIds.filter((id) => id !== major.id));
      return;
    }
    // チェックを外したら、閉じて、その大分類の中分類の選択も外す（見えないところで選ばれたまま残らないように）
    updateCheckedMajorIds(checkedMajorIds.filter((id) => id !== major.id));
    const middleIds = major.job_middle_categories.map((middle) => middle.id);
    onChange(selectedIds.filter((id) => !middleIds.includes(id)));
  }

  function setExpanded(majorId: number, expanded: boolean) {
    setCollapsedMajorIds(
      expanded ? collapsedMajorIds.filter((id) => id !== majorId) : [...collapsedMajorIds, majorId],
    );
  }

  function toggleMiddle(id: number, checked: boolean) {
    onChange(checked ? [...selectedIds, id] : selectedIds.filter((selectedId) => selectedId !== id));
  }

  return (
    <FieldSet>
      <FieldLegend variant="label">{legend}</FieldLegend>
      <div className="space-y-2">
        {majors.map((major) => {
          const majorId = `${name}-major-${major.id}`;
          const checked = checkedMajorIds.includes(major.id);
          const expanded = checked && !collapsedMajorIds.includes(major.id);
          const selectedCount = major.job_middle_categories.filter((middle) => selectedIds.includes(middle.id)).length;
          return (
            <Collapsible
              key={major.id}
              open={expanded}
              onOpenChange={(open) => setExpanded(major.id, open)}
              className="rounded-lg border p-3"
            >
              <div className="flex items-start gap-2">
                <Field orientation="horizontal" className="flex-1">
                  <Checkbox
                    id={majorId}
                    checked={checked}
                    onCheckedChange={(nextChecked) => toggleMajor(major, nextChecked)}
                  />
                  <FieldContent>
                    <FieldLabel htmlFor={majorId}>{major.name}</FieldLabel>
                    <FieldDescription>{major.description}</FieldDescription>
                  </FieldContent>
                </Field>
                {/* 開閉のボタンは、チェックを入れた大分類にだけ出す */}
                {checked && (
                  <div className="flex items-center gap-2">
                    {selectedCount > 0 && (
                      <span className="text-xs whitespace-nowrap text-muted-foreground">{selectedCount}件選択中</span>
                    )}
                    <CollapsibleTrigger
                      aria-label={`${major.name}の中分類を${expanded ? "閉じる" : "開く"}`}
                      className={buttonVariants({
                        variant: "ghost",
                        size: "icon-sm",
                        className: "[&[data-panel-open]>svg]:rotate-180",
                      })}
                    >
                      <ChevronDownIcon className="transition-transform" />
                    </CollapsibleTrigger>
                  </div>
                )}
              </div>

              {/* 中分類。開くときに、高さを変えてスッと出す（Base UI が --collapsible-panel-height に高さを入れる） */}
              <CollapsibleContent className="h-(--collapsible-panel-height) overflow-hidden transition-[height] duration-200 ease-out data-ending-style:h-0 data-starting-style:h-0">
                <div className="grid gap-2 pt-3 pl-6 sm:grid-cols-2">
                  {major.job_middle_categories.map((middle) => {
                    const middleId = `${name}-middle-${middle.id}`;
                    const disabled = disabledIds.includes(middle.id);
                    return (
                      <Field key={middle.id} orientation="horizontal" data-disabled={disabled ? true : undefined}>
                        <Checkbox
                          id={middleId}
                          checked={selectedIds.includes(middle.id)}
                          disabled={disabled}
                          onCheckedChange={(nextChecked) => toggleMiddle(middle.id, nextChecked)}
                          aria-invalid={errors ? true : undefined}
                        />
                        <FieldContent>
                          <FieldLabel htmlFor={middleId} className="font-normal">
                            {middle.name}
                            {disabled && `（${disabledNote}）`}
                          </FieldLabel>
                          <FieldDescription>{middle.description}</FieldDescription>
                        </FieldContent>
                      </Field>
                    );
                  })}
                </div>
              </CollapsibleContent>
            </Collapsible>
          );
        })}
      </div>
      <FieldError errors={errors?.map((message) => ({ message }))} />
    </FieldSet>
  );
}
