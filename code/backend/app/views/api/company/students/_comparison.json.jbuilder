# 学生詳細の、募集1件ぶんの比較（design/designs/API設計.md の 16-3 ㉓。順10）。
# 使い方：json.comparison { json.partial! "api/company/students/comparison", student: 学生, job_posting: 募集 }
#
# job_posting：右の列に出す募集の値。左の列（学生の値）は、㉓ の student をそのまま使う。
#   職種はメインとサブを1つにまとめる（学生の興味のある職種にもメイン・サブがなく、並べやすいため）。
#   カルチャーの5つは、学生の働き方の好み（黒丸）と重ねる白丸に使う。距離や「近いかどうか」は返さない（PR259）
# それ以外：一致の結果。判定は app/services/student_job_posting_comparison.rb の1か所で行い、画面は色を付けるだけ（16-1-9）

json.job_posting do
  json.industry_ids job_posting.job_posting_industries.map(&:industry_id)
  json.job_middle_category_ids job_posting.job_posting_job_categories.map(&:job_middle_category_id)
  json.technology_ids job_posting.job_posting_technologies.map(&:technology_id)
  json.extract! job_posting,
                :min_work_days_per_week, :min_work_hours_per_day, :min_duration_months, :start_month,
                :work_style, :prefecture_id,
                :culture_pace, :culture_novelty, :culture_collaboration, :culture_decision, :culture_atmosphere
end

json.merge! StudentJobPostingComparison.new(student: student, job_posting: job_posting).result
