# ㉝ GET /api/student/job_postings/:job_posting_id/similar_job_postings の形（design/designs/API設計.md の 16-3 ㉝）。
# 最大5件の形B を items で包む。ページ分けしない。
# 並び順は、稼働条件に合う募集が先、その中は近さの高い順（app/services/similar_job_postings.rb で並べ済み）

json.items @job_postings do |job_posting|
  json.partial! "api/student/job_postings/job_posting", job_posting: job_posting
end
