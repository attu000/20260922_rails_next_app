# ㉞ GET /api/student/candidacies の形（design/designs/API設計.md の 16-3-6、16-1-11）。
# 行は形B に、やりとりの番号（candidacy_id）と自分の状態（my_status）を足したもの（_row.json.jbuilder）

json.items @candidacies do |candidacy|
  json.partial! "api/student/candidacies/row", candidacy: candidacy
end
json.partial! "api/shared/pagination", pagy: @pagy
