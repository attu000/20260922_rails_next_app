# ⑳ GET /api/student/companies/:id の形（design/designs/API設計.md の 16-3 ⑳）。
# 業界・事業形態は、企業プロフィールの値（会社の紹介として表示する）。
# その企業とのスレッドがあるか（has_message_thread）は、順6 で足す（PR189）

json.id @company.id
json.name @company.name
json.industry_ids @company.industry_ids
json.business_type_ids @company.business_type_ids
# 番号ではなく名前（"size_10_49"）で返す。空欄なら null（16-1-8）
json.employee_size @company.employee_size
json.business_description @company.business_description
json.about @company.about
json.partial! "api/shared/icon_url", record: @company
# その企業の掲載中の募集。形B で、ページ分けしない（16-1-11）
json.job_postings @job_postings do |job_posting|
  json.partial! "api/student/job_postings/job_posting", job_posting: job_posting
end
