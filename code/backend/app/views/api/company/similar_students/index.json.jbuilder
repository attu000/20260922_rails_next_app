# ㉕ GET /api/company/students/:student_id/similar_students の形（design/designs/API設計.md の 16-3 ㉕）。
# 最大5人の形C を items で包む。ページ分けしない。
# 並び順は、稼働条件に合う学生が先、その中は近さの高い順（app/services/similar_students.rb で並べ済み）。
# 合う・合わないの区切りはポップアップに出さないので、matched は付けない

json.items @students do |student|
  json.partial! "api/company/students/row", student: student
end
