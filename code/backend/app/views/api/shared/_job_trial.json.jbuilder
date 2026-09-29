# プチ職業体験の講座の中身の形（design/designs/API設計.md の 16-3-9）。
# 学生向け（㊻）と企業向け（㊾）で同じ形にするため、ここ1か所で作る。
# with_answers：選択肢に正解（correct）と解説（explanation）を入れるか。
#   学生には入れない（㊼ で答えるたびに返す。PR377）。企業には最初から入れる（PR373）
# 解説・問題の文は Markdown のまま返し、画面で表示する（PR382）

json.extract! job_trial, :id, :title, :job_middle_category_id
# 工程の表示順（app/models/job_trial.rb）
json.work_process_ids job_trial.work_process_ids
json.intro job_trial.intro
# ハードルは講座の中の順番
json.hurdles job_trial.hurdles do |hurdle|
  json.extract! hurdle, :id, :name, :overview, :difficulty, :tips, :example, :goal, :question
  json.choices hurdle.choices do |choice|
    json.key choice["key"]
    json.body choice["body"]
    if with_answers
      json.correct choice["correct"]
      json.explanation choice["explanation"]
    end
  end
end
