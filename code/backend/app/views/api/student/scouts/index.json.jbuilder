# ㉟ GET /api/student/scouts の形（design/designs/API設計.md の 16-3-6、16-1-11）。
# ㉞ 募集管理と同じ形（_row.json.jbuilder）。my_status は常に scouted（スカウトあり）

json.items @candidacies do |candidacy|
  json.partial! "api/student/candidacies/row", candidacy: candidacy
end
json.partial! "api/shared/pagination", pagy: @pagy
