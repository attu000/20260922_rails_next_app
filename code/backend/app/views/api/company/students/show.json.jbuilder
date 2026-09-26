# ㉓ GET /api/company/students/:id の形（design/designs/API設計.md の 16-3-6）。
# has_message_thread は順6、comparison は順10、last_active_range は【仕上げ】で足す（16-3 ㉓ の作る順。PR208）

# 学生のプロフィール。マイページと同じ項目（マッチ前でもすべて見せる）
json.student do
  json.partial! "api/shared/student_profile", student: @student
end
# 自社の全募集。1件ずつ、その学生とのやりとりと押せるボタン（形D）
json.job_postings @job_postings do |job_posting|
  json.partial! "api/company/students/job_posting",
                job_posting: job_posting, candidacy: @candidacies_by_job_posting_id[job_posting.id]
end
