# ⑲ GET /api/student/job_postings/:id の形（design/designs/API設計.md の 16-3 ⑲）。
# 返さない項目：状態（代わりに is_open）と、目的・採用につながる可能性・求める人材（学生に見せない項目）。
# 次のものは、それを作る順で足す（PR189）
#   - 自分の状態（my_status、my_candidacy_id）：順5
#   - その企業とのスレッドがあるか（has_message_thread）：順6
#   - 業界・事業形態・工程、カルチャーの5つと自分の性格との比較（culture_comparison）：順9・順10

company = @job_posting.company_profile

json.extract! @job_posting, :id, :title
# 掲載中なら true。false なら、画面は「募集終了」と出す（順5 から、やりとりがある非公開・終了の募集も開けるようになる）
json.is_open @job_posting.published?
json.company do
  json.id company.id
  json.name company.name
  json.partial! "api/shared/icon_url", record: company
end
# どんな会社か・事業内容は、募集が空欄なら企業プロフィールの値を入れて返す（学生の画面では区別が要らないため）
json.about @job_posting.about || company.about.presence
json.business_description @job_posting.business_description || company.business_description.presence
json.extract! @job_posting,
              :internship_details, :growth,
              # 稼働条件
              :min_work_days_per_week, :min_work_hours_per_day, :min_duration_months, :start_month,
              :work_style, :work_style_note, :prefecture_id, :work_location_note, :weekend_ok, :work_note,
              :hourly_wage, :requirements, :preferred_requirements, :technology_note,
              # 職種は「主な／関連する」で配列を分けて返す（⑫と同じ名前）
              :main_job_middle_category_ids, :related_job_middle_category_ids,
              :technology_ids,
              :published_at
