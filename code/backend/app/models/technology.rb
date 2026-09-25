# 言語・フレームワーク・技術のマスタ（企業・学生で共通）。中身は db/seeds.rb で入れる（design/designs/その他決め事.md の 5-8）。
# マスタは名前で管理し、削除しない（技術構成.md の 9-1）
class Technology < ApplicationRecord
  # 区分。番号を明示し、新しい値は末尾に足す（技術構成.md の 9-1）
  enum :category, {
    language: 0,
    framework: 1,
    cloud: 2,
    other: 3
  }, validate: true

  validates :name, presence: true, uniqueness: true
  validates :position, presence: true

  # 表示順に並べる（区分ごとに、よく使われるものを上）。⑦ GET /api/options で返すときに使う
  scope :ordered, -> { order(:position) }
end
