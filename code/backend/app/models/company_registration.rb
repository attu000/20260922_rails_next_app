# 企業の新規登録（⑤ POST /api/company_registrations。design/designs/API設計.md の 16-3 ⑤）。
# 処理は親の Registration にある。ここでは種別とプロフィールの種類だけを決める。
# プロフィールの項目は、会社名・業界・事業形態・人数・事業内容・どんな会社か（会社情報の保存と同じ）
class CompanyRegistration < Registration
  ROLE = :company
  PROFILE_CLASS = CompanyProfile
end
