# ㊲ GET /api/company/students/:student_id/message_thread の形（design/designs/API設計.md の 16-3-7）。
# can_send は Rails が判定する（権限_バリデーション.md の 17-2-3）。画面は false なら送信欄を使えなくする。
# matched_job_postings は、その学生とマッチしている募集（【仕上げ】順16）。画面は名前を並べるだけ

json.partial! "api/shared/partner", record: @thread.student_profile
json.can_send @thread.can_send?
json.matched_job_postings @thread.matched_job_postings, :id, :title
json.messages @messages do |message|
  json.partial! "api/shared/message", message: message, viewer: Current.user
end
