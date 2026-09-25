# 学科のマスタ。「学部 → その学部の学科」の2段階で選ぶ。どの学部にも「その他」の学科がある（design/designs/ページ設計.md の 6-6 S1）
class Department < ApplicationRecord
  belongs_to :faculty

  validates :name, presence: true, uniqueness: { scope: :faculty_id }
  validates :position, presence: true
end
