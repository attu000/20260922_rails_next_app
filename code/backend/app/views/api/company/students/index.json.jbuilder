# ㉒ GET /api/company/students の形（design/designs/API設計.md の 16-3 ㉒、16-1-11）。
# 行は形C に matched（指定した条件を全部満たすか。Rails が判定する）を足したもの。
# 並び順は、合致の群がすべて先、そのあとに合致外の群（コントローラーと app/services/student_search.rb で並べ済み）。
# やりとりのタグ用の candidacy・candidacy_count は【仕上げ】で足す（仮の値は返さない）

json.items @students do |student|
  json.partial! "api/company/students/row", student: student
  json.matched @matched_ids.include?(student.id)
end
json.partial! "api/shared/pagination", pagy: @pagy, matched_count: @matched_count
