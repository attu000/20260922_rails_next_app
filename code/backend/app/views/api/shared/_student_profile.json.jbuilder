# 学生プロフィールの項目（design/designs/API設計.md の 16-3 ⑮）。
# ⑮ マイページと ㉓ 学生詳細（企業が見る。マッチ前でもすべて見せる）で使い回す。
# 使い方：json.partial! "api/shared/student_profile", student: 学生プロフィール
# 項目の名前と形は、⑥ 学生の新規登録で送るものと同じ（アカウントの項目は除く）。icon_url を加える。
# 空欄は null のまま返す。外部リンク・資格・就活希望エリアは【仕上げ】で足す（興味のある業界は順10 で前倒しした。PR254）

json.extract! student,
              :name, :university_id, :university_other_name, :faculty_id, :department_id, :grade,
              :graduation_year, :prefecture_id, :activity_status,
              :self_pr_strength, :self_pr_weakness, :self_pr_future,
              :work_days_per_week, :work_hours_per_day, :duration_months, :available_from,
              :can_full_remote, :can_partial_remote, :can_onsite, :work_note,
              # 働き方の好み（性格）の5軸。−2〜2 の数値
              :personality_pace, :personality_novelty, :personality_collaboration,
              :personality_decision, :personality_atmosphere,
              :interested_job_middle_category_ids, :interested_industry_ids, :commutable_prefecture_ids

# プログラミング歴。保存のたびに消して作り直すので、各行の番号（id）は返さない
json.skills student.student_skills do |skill|
  json.technology_id skill.technology_id
  json.other_name skill.other_name
  # 小数の列は、そのままだと "1.5" と文字列になるので、数値に直して返す（16-1-8）
  json.years skill.years&.to_f
  json.level skill.level
end

json.partial! "api/shared/icon_url", record: student
