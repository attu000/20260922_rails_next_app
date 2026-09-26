# 学生向けの募集の行（形B。design/designs/API設計.md の 16-3-2）。
# ⑱ 募集検索と ⑳ 企業詳細で使い回す。順5 以降の募集管理・スカウト管理でも使う。
# 使い方：json.partial! "api/student/job_postings/job_posting", job_posting: 募集
#
# 業界・事業形態・工程（industry_ids、business_type_ids、main_work_process_ids、involved_work_process_ids）は、
# 順9 で募集に足してから返す

json.extract! job_posting, :id, :title
# 掲載中なら true。false なら、画面は「募集終了」と出す（非公開か終了かの区別は、学生に見せない）
json.is_open job_posting.published?
json.company do
  json.id job_posting.company_profile.id
  json.name job_posting.company_profile.name
  json.partial! "api/shared/icon_url", record: job_posting.company_profile
end
json.extract! job_posting,
              :main_job_middle_category_ids, :related_job_middle_category_ids,
              :prefecture_id, :work_style, :hourly_wage,
              :min_work_days_per_week, :min_work_hours_per_day, :min_duration_months,
              :published_at
