// 使用技術を、区分（言語・フレームワーク・クラウド・その他）ごとの開閉する行から選ぶ入力欄。
// 各行に、その区分で選んでいる件数を出す。中はマスタのチェックボックスの部品を使い回す。
// 募集詳細編集の「使用言語・フレームワーク・技術」と、募集一覧（学生のホーム）の検索の条件で使い回す。
// 選ばれている技術の番号の一覧は、使う側（フォーム）が持つ

import { MasterCheckboxGroup } from "@/components/master-checkbox-group";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { FieldError, FieldLegend, FieldSet } from "@/components/ui/field";
import type { Options } from "@/lib/options";

type TechnologyPickerProps = {
  // 入力欄の名前。チェックボックスの id を作るのに使う（例："technology"）
  name: string;
  legend: string;
  options: Options;
  selectedIds: number[];
  onChange: (selectedIds: number[]) => void;
  // Rails や画面側の確認で見つかったエラー
  errors?: string[];
};

export function TechnologyPicker({ name, legend, options, selectedIds, onChange, errors }: TechnologyPickerProps) {
  return (
    <FieldSet>
      <FieldLegend variant="label">{legend}</FieldLegend>
      <Accordion multiple className="gap-2">
        {options.enums.technology_category.map((category) => {
          const rows = options.masters.technologies.filter((technology) => technology.category === category.value);
          const selectedCount = rows.filter((row) => selectedIds.includes(row.id)).length;
          return (
            <AccordionItem key={category.value} value={category.value} className="rounded-lg border">
              <AccordionTrigger className="items-center px-3 py-2 hover:no-underline">
                <span>{category.label}</span>
                {selectedCount > 0 && (
                  <span className="mr-2 ml-auto text-xs font-normal text-muted-foreground">
                    {selectedCount}件選択中
                  </span>
                )}
              </AccordionTrigger>
              <AccordionContent keepMounted className="px-3 pb-3">
                <MasterCheckboxGroup
                  name={`${name}-${category.value}`}
                  legend={category.label}
                  hideLegend
                  rows={rows}
                  selectedIds={selectedIds}
                  onChange={onChange}
                />
              </AccordionContent>
            </AccordionItem>
          );
        })}
      </Accordion>
      {/* エラーは開閉する行の外に出す（閉じたままでも見えるように） */}
      <FieldError errors={errors?.map((message) => ({ message }))} />
    </FieldSet>
  );
}
