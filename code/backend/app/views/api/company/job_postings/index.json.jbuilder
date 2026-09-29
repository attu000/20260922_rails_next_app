# ⑪ GET /api/company/job_postings の形（design/designs/API設計.md の 16-3 ⑪）。
# ページ分けしない一覧も items で包む（16-1-11）。
# 未対応の応募の件数（pending_application_count）は、候補者一覧の「未対応応募」のタグと同じ数え方（Candidacy.pending_application）

json.items @job_postings do |job_posting|
  json.extract! job_posting, :id, :title, :status, :published_at, :updated_at
  json.pending_application_count @pending_application_counts.fetch(job_posting.id, 0)
end
