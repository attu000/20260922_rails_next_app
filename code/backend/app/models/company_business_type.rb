# 企業の事業形態（企業×事業形態の中間テーブル）。design/designs/データベース.md の 8-5
class CompanyBusinessType < ApplicationRecord
  belongs_to :company_profile
  belongs_to :business_type
end
