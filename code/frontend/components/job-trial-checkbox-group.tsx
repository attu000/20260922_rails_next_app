// 募集詳細編集（C3）の「この募集に近いプチ職業体験」の欄（design/designs/ページ設計.md の C3。PR374）。
// 講座をすべて、講座の表示順に並べ、チェックを入れて選ぶ。おすすめの順番や一言は付けない。
// 講座名はプチ職業体験の内容（C11）へのリンクにし、新しいタブで開く（編集中の入力を失わないため）。
// 見た目は、業界などのチェックの一覧（components/master-checkbox-group.tsx）とそろえる

import Link from "next/link";
import { Checkbox } from "@/components/ui/checkbox";
import { Field, FieldError, FieldLegend, FieldSet } from "@/components/ui/field";
import type { JobTrialMaster } from "@/lib/options";

type JobTrialCheckboxGroupProps = {
  // ⑦ の masters.job_trials（講座の表示順）
  jobTrials: JobTrialMaster[];
  selectedIds: number[];
  onChange: (selectedIds: number[]) => void;
  // Rails の 422（「この募集に近いプチ職業体験に選べない値が含まれています」など）
  errors?: string[];
};

export function JobTrialCheckboxGroup({ jobTrials, selectedIds, onChange, errors }: JobTrialCheckboxGroupProps) {
  function toggle(id: number, checked: boolean) {
    onChange(checked ? [...selectedIds, id] : selectedIds.filter((selectedId) => selectedId !== id));
  }

  return (
    <FieldSet>
      {/* 開閉の見出しの行に同じ名前が出ているので、見出しは読み上げにだけ残す */}
      <FieldLegend variant="label" className="sr-only">
        この募集に近いプチ職業体験
      </FieldLegend>
      <div className="space-y-2">
        {jobTrials.map((jobTrial) => (
          <Field key={jobTrial.id} orientation="horizontal">
            {/* 講座名はリンクなので、チェック欄の名前は読み上げ用に付ける（押すとチェックが入る名札にはしない） */}
            <Checkbox
              aria-label={jobTrial.title}
              checked={selectedIds.includes(jobTrial.id)}
              onCheckedChange={(checked) => toggle(jobTrial.id, checked)}
              aria-invalid={errors ? true : undefined}
            />
            {/* 開いた先からこの画面を操作できないようにする（noopener noreferrer） */}
            <Link
              href={`/company/job_trials/${jobTrial.id}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm underline-offset-4 hover:underline"
            >
              {jobTrial.title}
            </Link>
          </Field>
        ))}
      </div>
      <FieldError errors={errors?.map((message) => ({ message }))} />
    </FieldSet>
  );
}
