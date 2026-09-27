# 募集の業界（募集×業界の中間テーブル）。design/designs/データベース.md の 8-5。
# 企業の業界（CompanyIndustry）とは別に持ち、検索・おすすめ・比較にはこちらを使う（その他決め事.md の 5-8）
class JobPostingIndustry < ApplicationRecord
  belongs_to :job_posting
  belongs_to :industry
end
