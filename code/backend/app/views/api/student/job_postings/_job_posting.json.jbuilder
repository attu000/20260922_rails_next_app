# 学生向けの募集の行（形B。design/designs/API設計.md の 16-3-2）。
# ⑱ 募集検索、⑳ 企業詳細、㉞ 募集管理、㉟ スカウト管理で使い回す。
# 使い方：json.partial! "api/student/job_postings/job_posting", job_posting: 募集
# 関連は、呼ぶ側が Api::Student::JobPostingsController::ROW_ASSOCIATIONS でまとめて読んでおく（N+1問題を避けるため）

json.extract! job_posting, :id, :title
# 掲載中なら true。false なら、画面は「募集終了」と出す（非公開か終了かの区別は、学生に見せない）
json.is_open job_posting.published?
json.company do
  json.id job_posting.company_profile.id
  json.name job_posting.company_profile.name
  json.partial! "api/shared/icon_url", record: job_posting.company_profile
end
json.extract! job_posting,
              # その募集の業界・事業形態。企業プロフィールの値では補わず、空欄なら空の配列（その他決め事.md の 5-8）
              :industry_ids, :business_type_ids,
              :main_job_middle_category_ids, :related_job_middle_category_ids,
              :main_work_process_ids, :involved_work_process_ids,
              :prefecture_id, :work_style, :hourly_wage,
              :min_work_days_per_week, :min_work_hours_per_day, :min_duration_months,
              :published_at
