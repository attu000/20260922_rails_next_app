# ㉞ GET /api/student/candidacies の形（design/designs/API設計.md の 16-3-6、16-1-11）。
# 行は形B に、やりとりの番号（candidacy_id）と自分の状態（my_status）を足したもの。
# my_status は applied（応募済み）か matched（マッチ済み）。企業側の見送り・合格・不合格は学生に見せない（Candidacy#my_status）

json.items @candidacies do |candidacy|
  json.partial! "api/student/job_postings/job_posting", job_posting: candidacy.job_posting
  json.candidacy_id candidacy.id
  json.my_status candidacy.my_status
end
json.partial! "api/shared/pagination", pagy: @pagy
