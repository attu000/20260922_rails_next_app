# ㊻ GET /api/student/job_trials/:id の形（design/designs/API設計.md の 16-3-9）。
# 講座の中身は、企業向け（㊾）と共通の形（app/views/api/shared/_job_trial.json.jbuilder）。
# 学生には正解と選択肢ごとの解説を返さない（㊼ で答えるたびに返す。PR377）

json.partial! "api/shared/job_trial", job_trial: @job_trial, with_answers: false
# 自分の自己分析（㊽ の返事と同じ形）。なければ null。
# 画面は、null でなければ「自己分析を書き直す」のボタンを出す（PR388）
if @self_analysis
  json.self_analysis do
    json.partial! "api/student/self_analyses/self_analysis", self_analysis: @self_analysis
  end
else
  json.self_analysis nil
end
