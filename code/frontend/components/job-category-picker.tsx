// 職種を「大分類 → 中分類」の2段階で選ぶ入力欄（design/designs/ページ設計.md の 6-5 C3、その他決め事.md の 5-7）。
// 大分類は常に表示し、チェックを入れた大分類の下に、中分類が開く。
// 募集詳細編集の「職種」、マイページの「興味のある職種」、募集一覧（学生のホーム）と学生検索（企業）の条件で使い回す。
// 選ばれている中分類の番号の一覧は、使う側（フォーム）が持つ。大分類のチェックと開閉は、この部品の中だけで覚える（保存しない）。
// 募集一覧・学生検索では「大分類だけ選んだ」ことも条件になるので、大分類のチェックを外に知らせる（onCheckedMajorsChange）。
//
// 大分類の枠の上の行（PR237・PR238。4か所とも同じ動き）
//   □ そのもの：チェックを付けて開く／チェックを外す（中の選択も外れる）
//   □ 以外（名前・説明・空いているところ・［⌄］）：チェックがなければ付けて開く。チェックがあれば開閉だけ（チェックは外れない）
//   … 開閉のつもりで名前を押して、選んだものが消えることがないようにするため
//
// 募集詳細編集では、チェックを入れた中分類の横に「メイン｜サブ」を出す（roles。PR234）

import { useState, type MouseEvent } from "react";
import { ChevronDownIcon } from "lucide-react";
import { RoleToggle } from "@/components/role-toggle";
import { buttonVariants } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import {
  Field,
  FieldContent,
  FieldDescription,
  FieldError,
  FieldLabel,
  FieldLegend,
  FieldSet,
  FieldTitle,
} from "@/components/ui/field";
import type { JobMajorCategory } from "@/lib/options";
import type { Role } from "@/lib/role-ids";

// メイン／サブを選ぶ形にするときに渡すもの（募集詳細編集だけ）
type RolesConfig = {
  // 選択肢（[{ value: "main", label: "メイン" }, { value: "sub", label: "サブ" }]）
  choices: { value: Role; label: string }[];
  // 中分類の番号 → メインかサブか
  roleOf: (middleId: number) => Role;
  onRoleChange: (middleId: number, role: Role) => void;
};

type JobCategoryPickerProps = {
  // 入力欄の名前。チェックボックスの id を作るのに使う（例："job-category"）
  name: string;
  legend: string;
  majors: JobMajorCategory[];
  selectedIds: number[];
  onChange: (selectedIds: number[]) => void;
  // Rails や画面側の確認で見つかったエラー
  errors?: string[];
  // 最初にチェックを入れておく大分類（募集一覧で、URL の job_major_category_ids から）。
  // 省略時は、選んでいる中分類を含む大分類だけにチェックを入れる
  initialCheckedMajorIds?: number[];
  // 大分類のチェックが変わったら知らせる（募集一覧で使う）
  onCheckedMajorsChange?: (majorIds: number[]) => void;
  // メイン／サブを選ぶ形にするとき（募集詳細編集）。なければチェックだけの一覧
  roles?: RolesConfig;
};

// 行を押したときの処理に届かないよう、クリックをそこで止める（□と［⌄］が、行の処理と二重に動かないようにするため）
function stopPropagation(event: MouseEvent) {
  event.stopPropagation();
}

export function JobCategoryPicker({
  name,
  legend,
  majors,
  selectedIds,
  onChange,
  errors,
  initialCheckedMajorIds = [],
  onCheckedMajorsChange,
  roles,
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
  // チェックは入っているが、閉じている大分類
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

  // 枠の上の行の、□以外の場所を押したとき（PR237）。チェックがなければ付けて開き、あれば開閉だけ
  function handleHeaderClick(major: JobMajorCategory, checked: boolean, expanded: boolean) {
    if (checked) {
      setExpanded(major.id, !expanded);
    } else {
      toggleMajor(major, true);
    }
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
          const majorNameId = `${majorId}-name`;
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
              {/* 枠の上の行。□以外のどこを押しても handleHeaderClick が動く */}
              <div
                className="flex cursor-pointer items-start gap-2"
                onClick={() => handleHeaderClick(major, checked, expanded)}
              >
                <Field orientation="horizontal" className="flex-1">
                  {/* 名前は□のラベルにしない（名前を押してチェックが外れないように）。読み上げ用に、名前を□に結び付ける */}
                  <Checkbox
                    id={majorId}
                    aria-labelledby={majorNameId}
                    checked={checked}
                    onCheckedChange={(nextChecked) => toggleMajor(major, nextChecked)}
                    onClick={stopPropagation}
                  />
                  <FieldContent>
                    <FieldTitle id={majorNameId}>{major.name}</FieldTitle>
                    <FieldDescription>{major.description}</FieldDescription>
                  </FieldContent>
                </Field>
                {/* 開閉のボタンは、チェックを入れた大分類にだけ出す。キーボードで開閉するために残す */}
                {checked && (
                  <div className="flex items-center gap-2">
                    {selectedCount > 0 && (
                      <span className="text-xs whitespace-nowrap text-muted-foreground">{selectedCount}件選択中</span>
                    )}
                    <CollapsibleTrigger
                      aria-label={`${major.name}の中分類を${expanded ? "閉じる" : "開く"}`}
                      onClick={stopPropagation}
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
                {/* メイン／サブを出すときは、横幅が要るので1列にする */}
                <div className={`grid gap-2 pt-3 pl-6 ${roles ? "" : "sm:grid-cols-2"}`}>
                  {major.job_middle_categories.map((middle) => {
                    const middleId = `${name}-middle-${middle.id}`;
                    const middleChecked = selectedIds.includes(middle.id);
                    return (
                      <div key={middle.id} className="flex items-start gap-2">
                        <Field orientation="horizontal" className="flex-1">
                          <Checkbox
                            id={middleId}
                            checked={middleChecked}
                            onCheckedChange={(nextChecked) => toggleMiddle(middle.id, nextChecked)}
                            aria-invalid={errors ? true : undefined}
                          />
                          <FieldContent>
                            <FieldLabel htmlFor={middleId} className="font-normal">
                              {middle.name}
                            </FieldLabel>
                            <FieldDescription>{middle.description}</FieldDescription>
                          </FieldContent>
                        </Field>
                        {/* チェックを入れた中分類だけ、メイン／サブを切り替えられる */}
                        {roles && middleChecked && (
                          <RoleToggle
                            label={`${middle.name}の区分`}
                            choices={roles.choices}
                            value={roles.roleOf(middle.id)}
                            onChange={(role) => roles.onRoleChange(middle.id, role)}
                          />
                        )}
                      </div>
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
