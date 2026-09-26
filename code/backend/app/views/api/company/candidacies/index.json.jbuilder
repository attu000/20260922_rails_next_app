# ㉑ GET /api/company/candidacies の形（design/designs/API設計.md の 16-3-6、16-1-11）。
# 行に出す学生の情報と並び順は、段階タグでは【仕上げ】だが、名前がないと誰の行か分からないので一緒に作った（PR207）。
# after_match は、その行がマッチ以降か。画面は true の行に「メッセージ」のボタンを出す（PR224）。
# 未返信（unreplied）は、メッセージのテーブルを作る順7 より後の【仕上げ】で足す

json.items @candidacies do |candidacy|
  json.id candidacy.id
  json.job_posting do
    json.extract! candidacy.job_posting, :id, :title, :status
  end
  json.student do
    student = candidacy.student_profile
    json.extract! student, :id, :name
    json.partial! "api/shared/icon_url", record: student
    json.extract! student, :grade, :graduation_year, :activity_status
  end
  json.extract! candidacy, :origin, :status
  # 企業から見たタグ。画面側では組み立てず、Rails の計算をそのまま出す（16-1-9。Candidacy#tag）
  json.set! :tag, candidacy.tag
  # マッチ以降か（Candidacy#after_match?）。「メッセージ」のボタンを出すかの判定も Rails で行う（16-1-9。PR224）
  json.after_match candidacy.after_match?
  # やりとりが始まった日時（応募日・スカウト日）と、マッチした日時
  json.extract! candidacy, :created_at, :matched_at
end
json.partial! "api/shared/pagination", pagy: @pagy
