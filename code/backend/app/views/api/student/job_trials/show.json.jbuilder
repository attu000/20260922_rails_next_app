# ㊻ GET /api/student/job_trials/:id の形（design/designs/API設計.md の 16-3-9）。
# 解説・問題の文は Markdown のまま返し、画面で表示する（PR382）。
# 企業向け（㊾。順19）と同じ形だが、学生には正解と選択肢ごとの解説を返さない（㊼ で答えるたびに返す。PR377）

json.extract! @job_trial, :id, :title, :job_middle_category_id
# 工程の表示順（app/models/job_trial.rb）
json.work_process_ids @job_trial.work_process_ids
json.intro @job_trial.intro
# ハードルは講座の中の順番
json.hurdles @job_trial.hurdles do |hurdle|
  json.extract! hurdle, :id, :name, :overview, :difficulty, :tips, :example, :goal, :question
  # 選択肢は key と本文だけ。正解（correct）と解説（explanation）は入れない
  json.choices hurdle.choices do |choice|
    json.key choice["key"]
    json.body choice["body"]
  end
end
# 自分の自己分析（㊽ の返事と同じ形）。なければ null。
# 画面は、null でなければ「自己分析を書き直す」のボタンを出す（PR388）
if @self_analysis
  json.self_analysis do
    json.partial! "api/student/self_analyses/self_analysis", self_analysis: @self_analysis
  end
else
  json.self_analysis nil
end
