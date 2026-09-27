# 募集の事業形態（募集×事業形態の中間テーブル）。design/designs/データベース.md の 8-5。
# 企業の事業形態（CompanyBusinessType）とは別に持ち、検索・おすすめ・比較にはこちらを使う（その他決め事.md の 5-8）
class JobPostingBusinessType < ApplicationRecord
  belongs_to :job_posting
  belongs_to :business_type
end
