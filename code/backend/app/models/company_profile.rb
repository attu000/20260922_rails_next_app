# 企業プロフィール。Phase 5 では会社名だけを持つ（design/designs/未決内容.md の 11-2）
class CompanyProfile < ApplicationRecord
  belongs_to :user

  # 会社名は必須、100文字まで（権限_バリデーション.md の 17-3-4）
  validates :name, presence: true, length: { maximum: 100 }
end
