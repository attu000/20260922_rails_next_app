# 企業向けの学生の行（形C。design/designs/API設計.md の 16-3-2）。
# ㉒ 学生検索で使う（【強み】の ㉕ 似た学生でも使い回す）。
# 使い方：json.partial! "api/company/students/row", student: 学生プロフィール
# 行には、スカウトするかどうかの判断に使う情報を絞って載せる。大学名などは学生詳細で見る。
# 最終活動の目安（last_active_range）は【仕上げ】で足す

json.extract! student, :id, :name
json.partial! "api/shared/icon_url", record: student
json.extract! student, :grade, :graduation_year, :activity_status
# 興味のある職種。まとめて読み込んだ中間テーブルから取り出す（1行ごとに問い合わせない。N+1問題を避ける）
json.interested_job_middle_category_ids student.student_interested_job_categories.map(&:job_middle_category_id)
# プログラミング歴。行では年数は出さない（形C）
json.skills student.student_skills do |skill|
  json.technology_id skill.technology_id
  json.other_name skill.other_name
  json.level skill.level
end
json.extract! student, :work_days_per_week, :work_hours_per_day, :duration_months
