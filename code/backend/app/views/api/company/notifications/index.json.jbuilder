# ㊷ GET /api/company/notifications の形（design/designs/API設計.md の 16-3-8、16-1-11）。
# read_at が null なら未読。link_path が `/` で始まるときだけリンクにする確認は、画面側で行う（ページ設計.md の 6-5 C10）。
# 対象の学生（student_profile_id）は、通知先を選ぶためにだけ使うので返さない

json.items @notifications do |notification|
  json.id notification.id
  json.kind notification.kind
  json.body notification.body
  json.link_path notification.link_path
  json.read_at notification.read_at
  json.created_at notification.created_at
end
json.partial! "api/shared/pagination", pagy: @pagy
