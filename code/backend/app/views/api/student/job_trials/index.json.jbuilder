# ㊺ GET /api/student/job_trials の形（design/designs/API設計.md の 16-3-9）。
# 中分類・工程の名前は、⑦ の masters から画面が引く

json.items @job_trials do |job_trial|
  json.extract! job_trial, :id, :title, :job_middle_category_id
  # 工程の表示順（app/models/job_trial.rb）
  json.work_process_ids job_trial.work_process_ids
  # 自分がその講座の自己分析を送っているか（修了済み。判定は Rails。PR369）
  json.completed @completed_job_trial_ids.include?(job_trial.id)
end
