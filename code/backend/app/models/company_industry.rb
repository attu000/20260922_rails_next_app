# 企業の業界（企業×業界の中間テーブル）。design/designs/データベース.md の 8-5
class CompanyIndustry < ApplicationRecord
  belongs_to :company_profile
  belongs_to :industry
end
