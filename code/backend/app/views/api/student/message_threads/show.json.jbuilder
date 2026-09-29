# ㊵ GET /api/student/companies/:company_id/message_thread の形（design/designs/API設計.md の 16-3-7）。
# can_send は Rails が判定する（権限_バリデーション.md の 17-2-3）。画面は false なら送信欄を使えなくする。
# matched_job_postings は、その企業とマッチしている募集（【仕上げ】順16）。企業側と同じ形で、合格・不合格の区別は返さない

json.partial! "api/shared/partner", record: @thread.company_profile
json.can_send @thread.can_send?
json.matched_job_postings @thread.matched_job_postings, :id, :title
json.messages @messages do |message|
  json.partial! "api/shared/message", message: message, viewer: Current.user
end
# 今マッチできるスカウト（PR222・PR223）。画面は、ここにある分だけ「マッチする」を出し、
# 押したら ㉜ POST /api/student/candidacies/:candidacy_id/match に送る。なければ空の配列
json.matchable_scouts @thread.matchable_scouts do |candidacy|
  json.candidacy_id candidacy.id
  json.job_posting do
    json.id candidacy.job_posting.id
    json.title candidacy.job_posting.title
  end
end
