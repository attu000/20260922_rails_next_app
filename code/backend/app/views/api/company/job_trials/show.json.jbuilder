# ㊾ GET /api/company/job_trials/:id の形（design/designs/API設計.md の 16-3-9）。
# 学生向け（㊻）と同じ形から自己分析を除き、選択肢に正解と解説を加えたもの（PR373）

json.partial! "api/shared/job_trial", job_trial: @job_trial, with_answers: true
