// 学生プロフィールの表示（読むだけ）。学生詳細（C6。企業が見る）で使う（design/designs/ページ設計.md の 6-5 C6、6-6 S1）。
// 項目はマイページ（S1）の入力項目と同じ。マッチ前でもすべて見せる。
// 名前とアイコンは、使う側の見出しに出すので、ここには入れない。
// 空欄の項目は「未入力」と出す（募集詳細と同じ部品）。
// 性格は順9、外部リンク・資格・興味のある業界・就活希望エリアは【仕上げ】で、Rails が返すようになってから足す

import { DetailItem, DetailSection } from "@/components/student-job-posting-detail";
import { formatStartMonth } from "@/lib/format";
import { jobMiddleCategoryNames, labelOf, nameOf, type Options } from "@/lib/options";
import type { StudentProfile, StudentSkill } from "@/lib/student-profile";

// 名前の一覧を「・」でつなぐ。空なら null（「未入力」と出す）
function joinNames(names: string[]): string | null {
  return names.length > 0 ? names.join("・") : null;
}

// 学部・学科。「工学部 情報工学科」のように並べる。どちらもなければ null
function facultyAndDepartment(student: StudentProfile, options: Options): string | null {
  const faculty = options.masters.faculties.find((row) => row.id === student.faculty_id);
  const department = faculty?.departments.find((row) => row.id === student.department_id);
  const names = [faculty?.name, department?.name].filter((name) => name !== undefined);
  return names.length > 0 ? names.join(" ") : null;
}

// プログラミング歴の1行。「Ruby　2.5年・v3 人に解説・教えることができる」（年数が空欄なら飛ばす）
function formatSkill(skill: StudentSkill, options: Options): string {
  const name = nameOf(options.masters.technologies, skill.technology_id) ?? skill.other_name ?? "";
  const details = [
    skill.years === null ? null : `${skill.years}年`,
    labelOf(options.enums.skill_level, skill.level),
  ].filter((part) => part !== null);
  return details.length > 0 ? `${name}　${details.join("・")}` : name;
}

// できる勤務形態（可能にしているものだけ）。表示名は ⑦ の enums.work_style
function workStyleNames(student: StudentProfile, options: Options): string[] {
  const styles = [
    student.can_full_remote ? "full_remote" : null,
    student.can_partial_remote ? "partial_remote" : null,
    student.can_onsite ? "onsite" : null,
  ];
  return styles.flatMap((style) => labelOf(options.enums.work_style, style) ?? []);
}

export function StudentProfileView({ student, options }: { student: StudentProfile; options: Options }) {
  return (
    <div className="space-y-6">
      {/* 並びは、ページ設計.md の 6-6 S1 の「表示（入力項目）」の順 */}
      <DetailSection title="基本情報">
        <DetailItem
          label="大学"
          // 一覧の大学がなければ、「その他」に書いた大学名
          value={nameOf(options.masters.universities, student.university_id) ?? student.university_other_name}
        />
        <DetailItem label="学部・学科" value={facultyAndDepartment(student, options)} />
        <DetailItem label="学年" value={labelOf(options.enums.grade, student.grade)} />
        <DetailItem
          label="卒業年度"
          value={student.graduation_year === null ? null : `${student.graduation_year}年卒`}
        />
        <DetailItem label="在住の都道府県" value={nameOf(options.masters.prefectures, student.prefecture_id)} />
        <DetailItem label="活動状況" value={labelOf(options.enums.activity_status, student.activity_status)} />
      </DetailSection>

      <DetailSection title="自己PR">
        <DetailItem label="自分の強み、向いていること" value={student.self_pr_strength} />
        <DetailItem label="向いていないこと" value={student.self_pr_weakness} />
        <DetailItem label="この先やりたいこと、挑戦したいこと" value={student.self_pr_future} />
      </DetailSection>

      <DetailSection title="プログラミング歴">
        <DetailItem
          label="言語・フレームワーク"
          // 1行に1つ（DetailItem は改行をそのまま出す）
          value={student.skills.length > 0 ? student.skills.map((skill) => formatSkill(skill, options)).join("\n") : null}
        />
      </DetailSection>

      <DetailSection title="就活状況">
        <DetailItem
          label="興味のある職種"
          value={joinNames(
            jobMiddleCategoryNames(options.masters.job_major_categories, student.interested_job_middle_category_ids),
          )}
        />
      </DetailSection>

      {/* 学生は「無理なく出せる量（上限）」を入れている（その他決め事.md の 5-6）。書き方はマイページの選択肢とそろえる */}
      <DetailSection title="稼働条件">
        <DetailItem
          label="週の稼働日数"
          value={student.work_days_per_week === null ? null : `週${student.work_days_per_week}日まで`}
        />
        <DetailItem
          label="1日の稼働時間"
          value={student.work_hours_per_day === null ? null : `1日${student.work_hours_per_day}時間まで`}
        />
        <DetailItem
          label="継続期間"
          value={student.duration_months === null ? null : `${student.duration_months}ヶ月以上続けられる`}
        />
        {/* 学生の開始時期の空欄は「随時」ではなく「未入力」（募集とは意味が違うため） */}
        <DetailItem
          label="開始時期"
          value={student.available_from === null ? null : formatStartMonth(student.available_from)}
        />
        <DetailItem label="できる勤務形態" value={joinNames(workStyleNames(student, options))} />
        <DetailItem
          label="出社できる都道府県"
          value={joinNames(
            student.commutable_prefecture_ids.flatMap((id) => nameOf(options.masters.prefectures, id) ?? []),
          )}
        />
        <DetailItem label="備考" value={student.work_note} />
      </DetailSection>
    </div>
  );
}
