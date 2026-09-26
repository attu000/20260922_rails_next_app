# ㊱ GET /api/company/message_threads の形（design/designs/API設計.md の 16-3-7、16-1-11）。
# partner は相手の学生。last_message_at は、メッセージがまだなければ（応募のマッチでできただけ）null

json.items @threads do |thread|
  json.id thread.id
  json.partial! "api/shared/partner", record: thread.student_profile
  json.last_message_at thread.last_message_at
end
json.partial! "api/shared/pagination", pagy: @pagy
