# ⑮ GET /api/student/profile の形。⑯ 保存の返事も同じ（design/designs/API設計.md の 16-3 ⑮）。
# 項目は、㉓ 学生詳細と共通の部品（app/views/api/shared/_student_profile.json.jbuilder）にまとめてある

json.partial! "api/shared/student_profile", student: @student
