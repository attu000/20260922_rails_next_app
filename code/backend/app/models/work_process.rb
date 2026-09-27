# 工程のマスタ。中身は db/seeds.rb で入れる（design/designs/その他決め事.md の 5-8）。
# マスタは名前で管理し、削除しない（技術構成.md の 9-1）
class WorkProcess < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :position, presence: true

  # 表示順（上流 → 下流）に並べる。⑦ GET /api/options で返すときに使う
  scope :ordered, -> { order(:position) }
end
