# ⑪ GET /api/company/job_postings の形（design/designs/API設計.md の 16-3 ⑪）。
# ページ分けしない一覧も items で包む（16-1-11）。
# 未対応の応募の件数（pending_application_count）は、やりとりのテーブルができてから【仕上げ】で足す

json.items @job_postings do |job_posting|
  json.extract! job_posting, :id, :title, :status, :published_at, :updated_at
end
