# ⑱ GET /api/student/job_postings の形（design/designs/API設計.md の 16-3 ⑱、16-1-11）。
# 行は形B に matched（指定した条件を全部満たすか。Rails が判定する）を足したもの。
# 並び順は、合致の群がすべて先、そのあとに合致外の群（コントローラーと app/services/job_posting_search.rb で並べ済み）

json.items @job_postings do |job_posting|
  json.partial! "api/student/job_postings/job_posting", job_posting: job_posting
  json.matched @matched_ids.include?(job_posting.id)
end
json.partial! "api/shared/pagination", pagy: @pagy, matched_count: @matched_count
