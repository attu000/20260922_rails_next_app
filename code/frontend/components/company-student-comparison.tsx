// 学生詳細（C6）の、募集タブの中に出す2つのまとまり（design/designs/ページ設計.md の 6-5 C6、API設計.md の 16-3 ㉓。順10）。
// - CandidacyReasons：応募理由・マッチ理由の12個の一覧。選んだ理由に ✓ を付ける（PR255）
// - JobPostingComparison：「この募集との比較」。左に学生、右に募集を並べ、一致したものをオレンジの枠と「一致」の文字で示す（PR256）。
//   カルチャーは1本の線に学生（黒丸）と募集（白丸）を重ねる（PR256・PR259）
// 一致・不一致の判定は Rails が返した結果（matched・result）を見るだけで、画面側では比べない（16-1-9）

import type { ReactNode } from "react";
import { CheckIcon } from "lucide-react";
import { CultureAxesView } from "@/components/culture-axes-field";
import { workStyleNames } from "@/components/student-profile-view";
import type { MatchedIds, StudentJobPostingComparison, WorkConditionItem } from "@/lib/company-students";
import { formatStartMonth } from "@/lib/format";
import { labelOf, nameOf, namesOf, type EnumOption, type Options } from "@/lib/options";
import type { StudentProfile } from "@/lib/student-profile";
import { cn } from "@/lib/utils";

// 空欄の側に出す言葉（プロフィールや募集詳細とそろえる）
const EMPTY_TEXT = "未入力";

// 一致したものの枠。色だけに頼らず「一致」の文字も添える（ページ設計.md の 6-5 C6）
const MATCHED_FRAME_CLASS = "border-highlight bg-highlight/30";

// ── 応募理由 ──

type CandidacyReasonsProps = {
  // 選んだ理由の英語の名前（"business" など）
  reasons: string[];
  // "application"（応募）／"scout"（スカウト）。見出しの言葉を変える
  origin: string;
  // ⑦ の enums.candidacy_reason（12個。画面に出す順）
  reasonOptions: EnumOption[];
};

// 応募理由・マッチ理由の12個の一覧。選んだ理由は ✓ を付けて濃く、選んでいない理由は薄く出す。
// 見るだけのものなので、押せるチェック欄にはしない（押せない欄は灰色で読みにくく、読み上げでも「押せる部品」と読まれるため）。
// 読み上げには、選んだ理由だけを読ませる
export function CandidacyReasons({ reasons, origin, reasonOptions }: CandidacyReasonsProps) {
  return (
    <section className="space-y-2">
      {/* 見出しは、下のプロフィールのまとまりの見出し（「基本情報」など）と同じ大きさ */}
      <h3 className="font-bold">{origin === "scout" ? "マッチ理由" : "応募理由"}</h3>
      <ul className="grid grid-cols-2 gap-x-4 gap-y-1 text-sm sm:grid-cols-3">
        {reasonOptions.map((option) => {
          const selected = reasons.includes(option.value);
          return (
            <li
              key={option.value}
              aria-hidden={selected ? undefined : true}
              className={cn("flex items-center gap-1", selected ? "font-medium" : "text-muted-foreground/60")}
            >
              {/* 選んでいない理由にも同じ幅の空きを取り、文字の頭をそろえる */}
              <CheckIcon aria-hidden="true" className={cn("size-4 shrink-0", !selected && "invisible")} />
              {option.label}
            </li>
          );
        })}
      </ul>
    </section>
  );
}

// ── この募集との比較 ──

type JobPostingComparisonProps = {
  student: StudentProfile;
  comparison: StudentJobPostingComparison;
  options: Options;
};

// 稼働条件の項目名（学生詳細のプロフィール・募集詳細と同じ言葉）
const WORK_CONDITION_LABELS: Record<WorkConditionItem, string> = {
  work_days_per_week: "週の稼働日数",
  work_hours_per_day: "1日の稼働時間",
  duration_months: "継続期間",
  start_month: "開始時期",
  work_style: "勤務形態",
  work_location: "勤務地",
};

export function JobPostingComparison({ student, comparison, options }: JobPostingComparisonProps) {
  const { masters } = options;
  const posting = comparison.job_posting;
  const middles = masters.job_major_categories.flatMap((major) => major.job_middle_categories);

  // 使用技術の学生側：プログラミング歴のうちマスタから選んだ技術と、「その他」の名前（「その他」は番号がないので一致にならない）
  const studentTechnologies = student.skills.map((skill) => ({
    id: skill.technology_id,
    name: nameOf(masters.technologies, skill.technology_id) ?? skill.other_name ?? "",
  }));

  // カルチャーの5軸を「軸の名前 → 数」の形に直す（募集詳細と同じ）。募集が本体（白丸）、学生が比べる相手（黒丸）
  const postingCulture: Record<string, number> = {
    pace: posting.culture_pace,
    novelty: posting.culture_novelty,
    collaboration: posting.culture_collaboration,
    decision: posting.culture_decision,
    atmosphere: posting.culture_atmosphere,
  };
  const studentPersonality: Record<string, number> = {
    pace: student.personality_pace,
    novelty: student.personality_novelty,
    collaboration: student.personality_collaboration,
    decision: student.personality_decision,
    atmosphere: student.personality_atmosphere,
  };

  return (
    <section className="space-y-4">
      {/* まとまりの見出しは画面には出さず、読み上げにだけ残す。見た目は「学生」「この募集」の列の見出しが代わりになる */}
      <h3 className="sr-only">この募集との比較</h3>

      {/* 列の見出し。下のプロフィールのまとまりの見出し（「基本情報」など）と同じ大きさ。
          業界・職種・使用技術・稼働条件の左右と同じ幅にそろえる */}
      <ComparisonRow label="" left={<ColumnHeading>学生</ColumnHeading>} right={<ColumnHeading>この募集</ColumnHeading>} />

      <ComparisonRow
        label="業界"
        left={
          <MatchedNames
            items={student.interested_industry_ids.map((id) => ({ id, name: nameOf(masters.industries, id) ?? "" }))}
            result={comparison.industry_ids}
          />
        }
        right={
          <MatchedNames
            items={posting.industry_ids.map((id) => ({ id, name: nameOf(masters.industries, id) ?? "" }))}
            result={comparison.industry_ids}
          />
        }
      />
      <ComparisonRow
        label="職種"
        left={
          <MatchedNames
            items={student.interested_job_middle_category_ids.map((id) => ({
              id,
              name: middles.find((middle) => middle.id === id)?.name ?? "",
            }))}
            result={comparison.job_middle_category_ids}
          />
        }
        right={
          <MatchedNames
            items={posting.job_middle_category_ids.map((id) => ({
              id,
              name: middles.find((middle) => middle.id === id)?.name ?? "",
            }))}
            result={comparison.job_middle_category_ids}
          />
        }
      />
      <ComparisonRow
        label="使用技術"
        left={<MatchedNames items={studentTechnologies} result={comparison.technology_ids} />}
        right={
          <MatchedNames
            items={posting.technology_ids.map((id) => ({ id, name: nameOf(masters.technologies, id) ?? "" }))}
            result={comparison.technology_ids}
          />
        }
      />

      <div className="space-y-2">
        <ItemHeading>稼働条件</ItemHeading>
        {comparison.work_conditions.map(({ item, result }) => (
          <div
            key={item}
            className={cn("rounded-md border px-2 py-1.5", result === "match" ? MATCHED_FRAME_CLASS : "border-transparent")}
          >
            <div className="flex items-center justify-between gap-2 text-xs text-muted-foreground">
              <span>{WORK_CONDITION_LABELS[item]}</span>
              {/* 判定できなかった（どちらかが未入力の）行には、何も付けない */}
              {result === "match" && <span className="font-medium text-foreground">一致</span>}
              {result === "mismatch" && <span>不一致</span>}
            </div>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <span>{studentWorkCondition(item, student, options) ?? EMPTY_TEXT}</span>
              <span>{postingWorkCondition(item, comparison, options) ?? EMPTY_TEXT}</span>
            </div>
          </div>
        ))}
      </div>

      <div className="space-y-2">
        <ItemHeading>カルチャー</ItemHeading>
        <CultureAxesView
          axes={options.culture_axes}
          values={postingCulture}
          compare={{ values: studentPersonality, label: "学生", baseLabel: "募集" }}
        />
      </div>
    </section>
  );
}

// 1つの項目の行：項目名と、左（学生）・右（募集）の2列
function ComparisonRow({ label, left, right }: { label: string; left: ReactNode; right: ReactNode }) {
  return (
    <div className="space-y-1">
      {label !== "" && <ItemHeading>{label}</ItemHeading>}
      <div className="grid grid-cols-2 gap-4">
        <div>{left}</div>
        <div>{right}</div>
      </div>
    </div>
  );
}

// 列の見出し（「学生」「この募集」）。プロフィールのまとまりの見出しと同じ大きさ
function ColumnHeading({ children }: { children: ReactNode }) {
  return <p className="font-bold">{children}</p>;
}

// 項目の見出し（「業界」「職種」「稼働条件」など）。列の見出しより一段小さい太字
function ItemHeading({ children }: { children: ReactNode }) {
  return <p className="text-sm font-bold">{children}</p>;
}

// 名前の札を並べる。Rails が「一致」とした番号（result.matched）に入っている札は、オレンジの枠と「一致」の文字を付ける。
// 並べるものがなければ「未入力」
function MatchedNames({ items, result }: { items: { id: number | null; name: string }[]; result: MatchedIds }) {
  if (items.length === 0) {
    return <p className="text-sm">{EMPTY_TEXT}</p>;
  }
  const matchedIds = result?.matched ?? [];
  return (
    <ul className="flex flex-wrap gap-1.5">
      {items.map((item, index) => {
        const matched = item.id !== null && matchedIds.includes(item.id);
        return (
          <li
            // 「その他」の技術は番号がないので、並びの位置も合わせて重ならないようにする
            key={`${item.id ?? "other"}-${index}`}
            className={cn(
              "inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-sm",
              matched && MATCHED_FRAME_CLASS,
            )}
          >
            {item.name}
            {matched && <span className="text-xs font-medium">一致</span>}
          </li>
        );
      })}
    </ul>
  );
}

// 稼働条件の学生の値。書き方は学生詳細のプロフィールとそろえる（学生は「無理なく出せる上限」。その他決め事.md の 5-6）。空欄なら null
function studentWorkCondition(item: WorkConditionItem, student: StudentProfile, options: Options): string | null {
  switch (item) {
    case "work_days_per_week":
      return student.work_days_per_week === null ? null : `週${student.work_days_per_week}日まで`;
    case "work_hours_per_day":
      return student.work_hours_per_day === null ? null : `1日${student.work_hours_per_day}時間まで`;
    case "duration_months":
      return student.duration_months === null ? null : `${student.duration_months}ヶ月以上続けられる`;
    case "start_month":
      // 学生の開始時期の空欄は「随時」ではなく「未入力」（募集とは意味が違うため）
      return student.available_from === null ? null : formatStartMonth(student.available_from);
    case "work_style":
      return joinNames(workStyleNames(student, options));
    case "work_location":
      return joinNames(namesOf(options.masters.prefectures, student.commutable_prefecture_ids));
  }
}

// 稼働条件の募集の値。書き方は募集詳細とそろえる（募集は「最低限ほしい下限」）。空欄なら null
function postingWorkCondition(item: WorkConditionItem, comparison: StudentJobPostingComparison, options: Options): string | null {
  const posting = comparison.job_posting;
  switch (item) {
    case "work_days_per_week":
      return posting.min_work_days_per_week === null ? null : `週${posting.min_work_days_per_week}日以上`;
    case "work_hours_per_day":
      return posting.min_work_hours_per_day === null ? null : `1日${posting.min_work_hours_per_day}時間以上`;
    case "duration_months":
      return posting.min_duration_months === null ? null : `最低${posting.min_duration_months}ヶ月以上`;
    case "start_month":
      // 募集の開始時期の空欄は「随時」
      return formatStartMonth(posting.start_month);
    case "work_style":
      return labelOf(options.enums.work_style, posting.work_style);
    case "work_location":
      // フルリモートなら勤務地を問わない（Rails も一致と判定する）
      if (posting.work_style === "full_remote") return "問わない（フルリモート）";
      return nameOf(options.masters.prefectures, posting.prefecture_id);
  }
}

// 名前の一覧を「・」でつなぐ。空なら null（「未入力」と出す）
function joinNames(names: string[]): string | null {
  return names.length > 0 ? names.join("・") : null;
}
